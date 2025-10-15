##############################################
# 🔹 Lambda Outputs
##############################################
output "lambda_name" {
  description = "Deployed Lambda function name"
  value       = module.lambda_with_logs.lambda_name
}

output "lambda_arn" {
  description = "Lambda function ARN"
  value       = module.lambda_with_logs.lambda_arn
}

output "lambda_invoke_arn" {
  description = "Lambda function Invoke ARN (used by API Gateway)"
  value       = module.lambda_with_logs.lambda_invoke_arn
}

output "lambda_log_group" {
  description = "CloudWatch log group name for Lambda logs"
  value       = module.lambda_with_logs.lambda_log_group
}

##############################################
# 🔹 Private API Gateway + PrivateLink Outputs
##############################################
output "api_id" {
  description = "Unique identifier for the API Gateway REST API"
  value       = module.apigw_private_privatelink.api_id
}

output "api_stage" {
  description = "Name of the deployed API Gateway stage"
  value       = module.apigw_private_privatelink.stage_name
}

output "vpce_id" {
  description = "ID of the created VPC Endpoint (Interface type for execute-api)"
  value       = module.apigw_private_privatelink.vpce_id
}

output "api_log_group" {
  description = "CloudWatch log group for API Gateway access logs"
  value       = module.apigw_private_privatelink.api_log_group
}

output "private_invoke_url" {
  description = "Private invoke URL for the API Gateway, accessible only from inside the VPC via PrivateLink"
  value       = module.apigw_private_privatelink.private_invoke_url
}
