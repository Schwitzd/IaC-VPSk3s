ephemeral "vault_kv_secret_v2" "ark_rabbitmq" {
  mount = var.vault_name
  name  = "ark-scraper-collector/rabbitmq"
}

ephemeral "vault_kv_secret_v2" "ark_mailer" {
  mount = var.vault_name
  name  = "ark-scraper-collector/mailer"
}

resource "kubernetes_secret_v1" "ark_rabbitmq" {
  metadata {
    name      = "auth-ark-rabbitmq"
    namespace = "stocks"
  }
  type = "Opaque"

  data_wo = {
    username = ephemeral.vault_kv_secret_v2.ark_rabbitmq.data["username"]
    password = ephemeral.vault_kv_secret_v2.ark_rabbitmq.data["password"]
  }
  data_wo_revision = 1
}

resource "kubernetes_secret_v1" "ark_mailer" {
  metadata {
    name      = "auth-ark-mailer"
    namespace = "stocks"
  }
  type = "Opaque"

  data_wo = {
    api_key = ephemeral.vault_kv_secret_v2.ark_mailer.data["mailer_api_key"]
  }
  data_wo_revision = 1
}
