variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to store beach data"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket to store beach data"
  type        = string
}

variable "s3_prefix" {
  description = "S3 key prefix for beach data"
  type        = string
  default     = "travel/beaches"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 900
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 1024
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}
