# IAM Module - Developer Access

################################################################################
# Developer IAM User
################################################################################

resource "aws_iam_user" "developer" {
  name = var.developer_username

  tags = merge(
    var.tags,
    {
      Name        = var.developer_username
      Description = "Read-only developer user for EKS cluster access"
    }
  )
}

# Attach AWS managed ReadOnlyAccess policy
resource "aws_iam_user_policy_attachment" "developer_readonly" {
  user       = aws_iam_user.developer.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Create access key for the developer user
resource "aws_iam_access_key" "developer" {
  user = aws_iam_user.developer.name
}

################################################################################
# Additional EKS Describe Policy
################################################################################

resource "aws_iam_user_policy" "developer_eks_describe" {
  name = "${var.developer_username}-eks-describe"
  user = aws_iam_user.developer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeAddon",
          "eks:ListAddons",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}