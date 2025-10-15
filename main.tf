terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {
  region = var.region
}

# 1) Lambda with logs
module "lambda_with_logs" {
  source                    = "./modules/lambda"
  lambda_function_name      = var.lambda_function_name
  lambda_handler            = var.lambda_handler
  lambda_runtime            = var.lambda_runtime
  lambda_zip_path           = var.lambda_zip_path
  lambda_environment        = var.lambda_environment
}

module "apigw_private_privatelink" {
  source              = "./modules/api_gateway_lambda"

  # --- Required Networking Inputs ---
  vpc_id              = var.vpc_id
  private_subnet_ids  = var.private_subnet_ids
  vpce_ingress_cidrs  = var.vpce_ingress_cidrs

  # --- Lambda Inputs ---
  region             = var.region
  lambda_name        = module.lambda_with_logs.lambda_name
  lambda_invoke_arn  = module.lambda_with_logs.lambda_invoke_arn

  # --- API Gateway Config ---
  api_name               = var.api_name
  resource_path          = var.resource_path
  http_method            = var.http_method
  stage_name             = var.stage_name
  api_log_retention_days = var.api_log_retention_days
  api_log_level          = var.api_log_level
  depends_on = [aws_api_gateway_account.account_settings]
}
# IAM role that allows API Gateway to write logs to CloudWatch
resource "aws_iam_role" "apigw_cloudwatch_role" {
  name = "APIGatewayCloudWatchLogsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach AWS managed policy for CloudWatch logging
resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_policy" {
  role       = aws_iam_role.apigw_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# Set this IAM role as the account-level CloudWatch Logs role for API Gateway
resource "aws_api_gateway_account" "account_settings" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}
