# Serverless Module - Variables

variable "assets_bucket_name" {
  description = "Name of the S3 bucket for assets"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_source_dir" {
  description = "Directory containing Lambda source code"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}