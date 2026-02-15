# Observability Module - Outputs

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for EKS"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch Log Group for EKS"
  value       = aws_cloudwatch_log_group.eks_cluster.arn
}

output "cloudwatch_observability_role_arn" {
  description = "ARN of the IAM role for CloudWatch Observability"
  value       = aws_iam_role.cloudwatch_observability.arn
}

output "application_log_group_name" {
  description = "Name of the CloudWatch log group for retail-store-sample-app logs"
  value       = aws_cloudwatch_log_group.application_logs.name
}

output "dataplane_log_group_name" {
  description = "Name of the CloudWatch log group for dataplane logs"
  value       = aws_cloudwatch_log_group.dataplane_logs.name
}

output "fluent_bit_role_arn" {
  description = "ARN of the IAM role for FluentBit"
  value       = aws_iam_role.fluent_bit.arn
}

output "cloudwatch_namespace" {
  description = "Kubernetes namespace for CloudWatch resources"
  value       = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
}

# output "cloudwatch_addon_id" {
#   description = "ID of the CloudWatch Observability add-on"
#   value       = aws_eks_addon.cloudwatch_observability.id
# }