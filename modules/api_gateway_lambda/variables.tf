###########################################
# Networking
###########################################
variable "region" {
  description = "AWS region where the API Gateway and VPC Endpoint will be created"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the Interface VPC Endpoint for execute-api will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used for creating the Interface VPC Endpoint"
  type        = list(string)
}

variable "vpce_ingress_cidrs" {
  description = "CIDR ranges allowed to access the VPC Endpoint on port 443"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

###########################################
# Lambda Integration
###########################################
variable "lambda_name" {
  description = "Lambda function name for API Gateway integration"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda function invoke ARN (used in AWS_PROXY integration)"
  type        = string
}

###########################################
# API Gateway Configuration
###########################################
variable "api_name" {
  description = "Name of the API Gateway (used in resource naming)"
  type        = string
}

variable "resource_path" {
  description = "Resource path (e.g., orders, products)"
  type        = string
}

variable "http_method" {
  description = "HTTP method for API Gateway (GET, POST, PUT, DELETE)"
  type        = string
  default     = "POST"
}

variable "stage_name" {
  description = "Deployment stage name (e.g., dev, qa, prod)"
  type        = string
  default     = "dev"
}

###########################################
# Logging and Monitoring
###########################################
variable "api_log_retention_days" {
  description = "Number of days to retain CloudWatch API Gateway access logs"
  type        = number
  default     = 14
}

variable "api_log_level" {
  description = "API Gateway stage logging level (OFF, ERROR, INFO)"
  type        = string
  default     = "INFO"
}
