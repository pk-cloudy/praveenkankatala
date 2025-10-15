############################################
# Lambda Module Outputs
############################################
output "lambda_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.lambda_func.function_name
}

output "lambda_arn" {
  description = "ARN of the created Lambda function"
  value       = aws_lambda_function.lambda_func.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN for API Gateway integration (used by AWS_PROXY)"
  value       = aws_lambda_function.lambda_func.invoke_arn
}

output "lambda_log_group" {
  description = "CloudWatch Log Group name for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
