# Kubernetes RBAC Module - Variables

variable "developer_iam_arn" {
  description = "ARN of the developer IAM user"
  type        = string
}

variable "node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  type        = string
}

variable "app_namespace" {
  description = "Kubernetes namespace for the retail application"
  type        = string
}