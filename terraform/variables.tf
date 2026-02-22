# Variables for Project Bedrock Infrastructure

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "student_id" {
  description = "Student ID for unique resource naming"
  type        = string
  default     = "ALT/SOE/025/1483"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "project-bedrock-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.34"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "project-bedrock-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

variable "node_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "developer_username" {
  description = "IAM username for developer read-only access"
  type        = string
  default     = "bedrock-dev-view"
}

variable "s3_assets_bucket_suffix" {
  description = "Suffix for S3 assets bucket"
  type        = string
  default     = "alt-soe-025-1483"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "bedrock-asset-processor"
}

variable "app_namespace" {
  description = "Kubernetes namespace for the retail application"
  type        = string
  default     = "retail-app"
}

variable "enable_alb_ingress" {
  description = "Enable ALB Ingress Controller (bonus feature)"
  type        = bool
  default     = false
}

variable "enable_k8s_rbac" {
  description = "Enable Kubernetes RBAC module (requires admin credentials)"
  type        = bool
  default     = true
}
