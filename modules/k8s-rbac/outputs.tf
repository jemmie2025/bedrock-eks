# Kubernetes RBAC Module - Outputs

output "retail_app_namespace" {
  description = "Name of the retail application namespace"
  value       = kubernetes_namespace.retail_app.metadata[0].name
}

output "retail_app_service_account" {
  description = "Name of the retail application service account"
  value       = kubernetes_service_account.retail_app.metadata[0].name
}

output "developer_group" {
  description = "Name of the developer group for RBAC"
  value       = "view-only-group"
}