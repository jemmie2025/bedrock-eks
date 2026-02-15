# Observability Module - Variables

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
}

variable "cloudwatch_addon_version" {
  description = "Version of the CloudWatch Observability add-on"
  type        = string
  default     = "v1.0.0-eksbuild.1"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}