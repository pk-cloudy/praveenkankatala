###########################################
# 🌎 Global / AWS provider configuration
###########################################
variable "region" {
  description = "AWS region to deploy the infrastructure in"
  type        = string
  default     = "us-east-1"
}

###########################################
# 🌐 Networking
###########################################
variable "vpc_id" {
  description = "ID of the existing VPC to associate the private API Gateway endpoint with"
  type        = string
  default     = "vpc-093e3b492232b75cc"
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs within the VPC for the Interface VPC Endpoint"
  type        = list(string)
  default     = ["subnet-0c2667c81c2ae1a7c", "subnet-0f739c6f7f8a7519a"]
}

variable "vpce_ingress_cidrs" {
  description = "CIDR ranges that can access the VPC endpoint over HTTPS (usually internal CIDR)"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

###########################################
# 🧠 Lambda configuration
###########################################
variable "lambda_function_name" {
  description = "Unique name for the Lambda function"
  type        = string
  default     = "my-private-lambda"
}

variable "lambda_handler" {
  description = "Lambda handler (entrypoint), e.g., index.handler"
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Lambda runtime environment"
  type        = string
  default     = "python3.9"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package ZIP file"
  type        = string
  default     = "lambda_function.zip"
}

variable "lambda_log_retention_days" {
  description = "Number of days to retain CloudWatch logs for Lambda"
  type        = number
  default     = 14
}

variable "lambda_environment" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {
    LOG_LEVEL = "INFO"
  }
}

###########################################
# 🚀 API Gateway configuration
###########################################
variable "api_name" {
  description = "Name of the private API Gateway"
  type        = string
  default     = "internal-private-api"
}

variable "resource_path" {
  description = "Path part (resource name) of the API Gateway resource"
  type        = string
  default     = "orders"
}

variable "http_method" {
  description = "HTTP method for the API Gateway resource"
  type        = string
  default     = "POST"
}

variable "stage_name" {
  description = "Stage name for API Gateway deployment (e.g., dev, qa, prod)"
  type        = string
  default     = "dev"
}

###########################################
# 📊 API Logging
###########################################
variable "api_log_retention_days" {
  description = "Number of days to retain CloudWatch access logs for API Gateway"
  type        = number
  default     = 14
}

variable "api_log_level" {
  description = "Logging level for API Gateway stage (INFO, ERROR, etc.)"
  type        = string
  default     = "INFO"
}
