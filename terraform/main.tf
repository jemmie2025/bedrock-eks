# Main Terraform Configuration for Project Bedrock

locals {
  common_tags = {
    Project   = "barakat-2025-capstone"
    ManagedBy = "Terraform"
  }
}

################################################################################
# Data Sources
################################################################################

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "./modules/vpc"

  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = var.cluster_name

  tags = merge(local.common_tags, {
    Name = var.vpc_name
  })
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "./modules/eks"

  cluster_name              = var.cluster_name
  cluster_version           = var.cluster_version
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  node_group_desired_size   = var.node_group_desired_size
  node_group_min_size       = var.node_group_min_size
  node_group_max_size       = var.node_group_max_size
  node_instance_types       = var.node_instance_types

  tags = local.common_tags
}

################################################################################
# IAM Developer User
################################################################################

module "iam" {
  source = "./modules/iam"

  developer_username = var.developer_username
  cluster_name       = var.cluster_name
  cluster_arn        = module.eks.cluster_arn

  tags = local.common_tags
}

################################################################################
# S3 and Lambda for Event-Driven Processing
################################################################################

module "serverless" {
  source = "./modules/serverless"

  assets_bucket_name  = "bedrock-assets-${var.s3_assets_bucket_suffix}"
  lambda_function_name = var.lambda_function_name
  lambda_source_dir    = "${path.root}/../lambda"

  tags = local.common_tags
}

################################################################################
# CloudWatch Logging
################################################################################

module "observability" {
  source = "./modules/observability"

  aws_region          = var.aws_region
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  cluster_endpoint    = module.eks.cluster_endpoint
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url

  tags = local.common_tags

  depends_on = [module.eks]
}

################################################################################
# Kubernetes RBAC for Developer Access
################################################################################

module "k8s_rbac" {
  source = "./modules/k8s-rbac"
  count  = var.enable_k8s_rbac ? 1 : 0

  developer_iam_arn = module.iam.developer_user_arn
  node_role_arn     = module.eks.node_group_role_arn
  app_namespace     = var.app_namespace

  depends_on = [module.eks]
}

################################################################################
# RDS Databases (Bonus)
################################################################################

module "rds" {
  source = "./modules/rds"
  count  = var.enable_rds ? 1 : 0

  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  eks_security_group_id = module.eks.node_security_group_id

  tags = local.common_tags
}

################################################################################
# AWS Load Balancer Controller (Bonus)
################################################################################

module "alb_controller" {
  source = "./modules/alb-controller"
  count  = var.enable_alb_ingress ? 1 : 0

  cluster_name       = var.cluster_name
  cluster_endpoint   = module.eks.cluster_endpoint
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  vpc_id             = module.vpc.vpc_id

  tags = local.common_tags

  depends_on = [module.eks]
}