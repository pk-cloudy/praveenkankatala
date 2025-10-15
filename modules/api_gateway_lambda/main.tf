############################################
# Interface VPC Endpoint for API Gateway (execute-api)
############################################

resource "aws_security_group" "vpce_sg" {
  name        = "${var.api_name}-vpce-sg"
  description = "SG for API Gateway VPC endpoint (execute-api)"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.vpce_ingress_cidrs
    content {
      description = "Allow HTTPS from CIDR"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.api_name}-vpce-sg" }
}

resource "aws_vpc_endpoint" "execute_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true

  tags = { Name = "${var.api_name}-execute-api-vpce" }
}

############################################
# CloudWatch Log Group for API Gateway access logs
############################################
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.api_log_retention_days
}

############################################
# API Gateway (REST) — PRIVATE + bound to VPC Endpoint
############################################
resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "Private REST API (PrivateLink) that invokes Lambda via AWS_PROXY"

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.execute_api.id]
  }
}

# Resource (e.g., /orders)
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = var.resource_path
}

# Method (e.g., POST)
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = var.http_method
  authorization = "NONE"
}

# Direct Lambda integration via AWS_PROXY
resource "aws_api_gateway_integration" "lambda_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# Deploy & Stage
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  depends_on  = [aws_api_gateway_integration.lambda_proxy]

  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.deployment.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationErr = "$context.integrationErrorMessage"
    })
  }

  variables = { log_level = var.api_log_level }
  depends_on = [aws_cloudwatch_log_group.api_logs]
}

############################################
# Resource Policy — allow ONLY this VPC Endpoint to invoke
############################################
data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api_policy" "policy" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowInvokeFromSpecificVPCE",
      Effect    = "Allow",
      Principal = "*",
      Action    = "execute-api:Invoke",
      Resource  = "arn:aws:execute-api:${var.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.this.id}/*/*/*",
      Condition = {
        StringEquals = {
          "aws:SourceVpce" = aws_vpc_endpoint.execute_api.id
        }
      }
    }]
  })
}

############################################
# Lambda permission for API Gateway
############################################
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowPrivateApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}
