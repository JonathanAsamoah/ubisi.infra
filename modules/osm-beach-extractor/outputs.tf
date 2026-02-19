output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "service_user_name" {
  description = "Name of the IAM service user with S3 read/write access"
  value       = aws_iam_user.s3_service.name
}

output "service_user_arn" {
  description = "ARN of the IAM service user with S3 read/write access"
  value       = aws_iam_user.s3_service.arn
}
