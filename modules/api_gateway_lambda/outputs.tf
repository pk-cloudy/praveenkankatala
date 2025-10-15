############################################
# API Gateway PrivateLink Module Outputs
############################################
output "api_id" {
  description = "Unique ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.this.id
}

output "stage_name" {
  description = "Deployed API Gateway stage name"
  value       = aws_api_gateway_stage.stage.stage_name
}

output "vpce_id" {
  description = "Interface VPC Endpoint ID for API Gateway (execute-api)"
  value       = aws_vpc_endpoint.execute_api.id
}

output "api_log_group" {
  description = "CloudWatch log group for API Gateway access logs"
  value       = aws_cloudwatch_log_group.api_logs.name
}

output "private_invoke_url" {
  description = "Private API invoke URL (accessible only inside the VPC via PrivateLink)"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.region}.amazonaws.com/${var.stage_name}/${var.resource_path}"
}
