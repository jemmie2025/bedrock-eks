# Observability Module - CloudWatch Logging

################################################################################
# CloudWatch Log Groups for EKS Control Plane
################################################################################

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  lifecycle {
    ignore_changes = [kms_key_id]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-cluster-logs"
    }
  )
}

################################################################################
# IAM Role for CloudWatch Observability Add-on
################################################################################

data "aws_iam_policy_document" "cloudwatch_observability_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "cloudwatch_observability" {
  name               = "${var.cluster_name}-cloudwatch-observability-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_observability_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_observability.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_xray" {
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
  role       = aws_iam_role.cloudwatch_observability.name
}

################################################################################
# EKS Add-on: Amazon CloudWatch Observability
################################################################################

# CloudWatch Observability add-on temporarily disabled due to version compatibility issues with EKS 1.34
# Can be enabled later by uncommenting the resource below
# resource "aws_eks_addon" "cloudwatch_observability" {
#   cluster_name             = var.cluster_name
#   addon_name               = "amazon-cloudwatch-observability"
#   addon_version            = var.cloudwatch_addon_version
#   service_account_role_arn = aws_iam_role.cloudwatch_observability.arn
#
#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.cluster_name}-cloudwatch-observability-addon"
#     }
#   )
# }

################################################################################
# Alternative: FluentBit for Container Logs (if add-on not available)
################################################################################

# Uncomment if you want to use FluentBit instead of the CloudWatch Observability add-on

# resource "aws_iam_role" "fluent_bit" {
#   name = "${var.cluster_name}-fluent-bit-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRoleWithWebIdentity"
#       Effect = "Allow"
#       Principal = {
#         Federated = var.oidc_provider_arn
#       }
#       Condition = {
#         StringEquals = {
#           "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:amazon-cloudwatch:fluent-bit"
#           "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
#         }
#       }
#     }]
#   })
#
#   tags = var.tags
# }
#
# resource "aws_iam_role_policy_attachment" "fluent_bit" {
#   policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
#   role       = aws_iam_role.fluent_bit.name
# }