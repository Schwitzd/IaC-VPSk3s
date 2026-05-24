data "vault_generic_secret" "cert_manager" {
  path = "${var.vault_name}/cert-manager"
}

resource "kubernetes_secret_v1" "cloudflare_api_token" {
  metadata {
    name      = "auth-api-cloudflare"
    namespace = "pki"
  }

  type = "Opaque"

  data = {
    "api-token" = "${data.vault_generic_secret.cert_manager.data.cloudflare_api}"
  }
}
