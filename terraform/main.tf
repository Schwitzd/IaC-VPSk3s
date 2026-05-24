# Namespaces
resource "kubernetes_namespace_v1" "namespaces" {
  for_each = toset(local.namespaces)

  metadata {
    name = each.key
  }
}