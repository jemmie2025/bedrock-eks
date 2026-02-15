# IAM Module - Variables

variable "developer_username" {
  description = "IAM username for developer read-only access"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}