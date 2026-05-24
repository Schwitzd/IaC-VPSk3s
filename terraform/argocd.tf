resource "kubernetes_manifest" "argocd_manager_sa" {
  manifest = yamldecode(file("${path.module}/argocd-manager-sa.yaml"))
}

resource "kubernetes_manifest" "argocd_manager_crb" {
  manifest = yamldecode(file("${path.module}/argocd-manager-crb.yaml"))

  depends_on = [
    kubernetes_manifest.argocd_manager_sa
  ]
}
