# Terraform Outputs for Grading

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "assets_bucket_name" {
  description = "Name of the S3 assets bucket"
  value       = module.serverless.assets_bucket_name
}

output "developer_access_key_id" {
  description = "Access Key ID for bedrock-dev-view user"
  value       = module.iam.developer_access_key_id
  sensitive   = true
}

output "developer_secret_access_key" {
  description = "Secret Access Key for bedrock-dev-view user"
  value       = module.iam.developer_secret_access_key
  sensitive   = true
}

output "lambda_function_name" {
  description = "Name of the Lambda asset processor function"
  value       = module.serverless.lambda_function_name
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups for monitoring"
  value = {
    cluster_logs                  = module.observability.cloudwatch_log_group_name
    retail_store_sample_app_logs  = module.observability.application_log_group_name
    dataplane_logs                = module.observability.dataplane_log_group_name
  }
}

output "view_logs_commands" {
  description = "Commands to view logs in CloudWatch"
  value = {
    cluster_logs     = "aws logs tail ${module.observability.cloudwatch_log_group_name} --follow"
    application_logs = "aws logs tail ${module.observability.application_log_group_name} --follow"
    lambda_logs      = "aws logs tail /aws/lambda/${module.serverless.lambda_function_name} --follow"
  }
}