###########################################
# Lambda Configuration Inputs
###########################################
variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "lambda_handler" {
  description = "Lambda handler (entrypoint, e.g., index.handler)"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime environment (e.g., python3.9, nodejs18.x)"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to Lambda deployment package (ZIP file)"
  type        = string
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain CloudWatch logs for Lambda"
  type        = number
  default     = 14
}

variable "lambda_environment" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}
