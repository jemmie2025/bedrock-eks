# Kubernetes RBAC Module - Developer Access

################################################################################
# Namespace for Retail Application
################################################################################

resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = var.app_namespace

    labels = {
      name        = var.app_namespace
      environment = "production"
      project     = "bedrock"
    }
  }
}

################################################################################
# ConfigMap for AWS Auth (Developer Access)
################################################################################

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = var.node_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])
    mapUsers = yamlencode([
      {
        userarn  = var.developer_iam_arn
        username = "bedrock-dev-view"
        groups   = ["view-only-group"]
      }
    ])
  }

  force = true
}

################################################################################
# ClusterRoleBinding for View Access
################################################################################

resource "kubernetes_cluster_role_binding" "developer_view" {
  metadata {
    name = "bedrock-developer-view-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "Group"
    name      = "view-only-group"
    api_group = "rbac.authorization.k8s.io"
  }
}

################################################################################
# Additional RoleBinding for retail-app namespace
################################################################################

resource "kubernetes_role_binding" "developer_retail_app" {
  metadata {
    name      = "bedrock-developer-retail-app-binding"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "Group"
    name      = "view-only-group"
    api_group = "rbac.authorization.k8s.io"
  }
}

################################################################################
# Service Account for Application (optional)
################################################################################

resource "kubernetes_service_account" "retail_app" {
  metadata {
    name      = "retail-app-sa"
    namespace = kubernetes_namespace.retail_app.metadata[0].name

    labels = {
      app     = "retail-store"
      project = "bedrock"
    }
  }
}