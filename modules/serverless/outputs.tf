# Serverless Module - Outputs

output "assets_bucket_name" {
  description = "Name of the S3 assets bucket"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_arn" {
  description = "ARN of the S3 assets bucket"
  value       = aws_s3_bucket.assets.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.asset_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.asset_processor.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda IAM role"
  value       = aws_iam_role.lambda.arn
}