ephemeral "vault_kv_secret_v2" "rabbitmq_definitions" {
  mount = var.vault_name
  name  = "rabbitmq/definitions"
}

resource "kubernetes_secret_v1" "rabbitmq_definitions" {
  metadata {
    name      = "rabbitmq-definitions"
    namespace = "queue"
  }

  type = "Opaque"

  data_wo = {
    "defs.json" = ephemeral.vault_kv_secret_v2.rabbitmq_definitions.data["defs.json"]
  }
  data_wo_revision = 1
}

# TLS cert for AMQPS
#resource "kubernetes_manifest" "cert_rabbitmq_amqps" {
#  manifest = {
#    apiVersion = "cert-manager.io/v1"
#    kind       = "Certificate"
#    metadata = {
#      name      = "rabbitmq-amqps"
#      namespace = "queue"
#    }
#    spec = {
#      secretName = "tls-rabbitmq-amqps"
#      issuerRef = {
#        name = "le-clusterissuer"
#        kind = "ClusterIssuer"
#      }
#      dnsNames = ["mq.vps.schwitzd.me"]
#    }
#  }
#}

# Traefik TCP ingress for AMQPS
#resource "kubernetes_manifest" "rabbitmq_ingressroutetcp_amqps" {
#  manifest = {
#    apiVersion = "traefik.io/v1alpha1"
#    kind       = "IngressRouteTCP"
#    metadata = {
#      name      = "rabbitmq-amqps"
#      namespace = "queue"
#    }
#    spec = {
#      entryPoints = ["amqps"]
#      routes = [
#        {
#          match = "HostSNI(`mq.vps.schwitzd.me`)"
#          services = [
#            {
#              name = "rabbitmq"
#              port = 5672
#            }
#          ]
#        }
#      ]
#      tls = {
#        secretName = "tls-rabbitmq-amqps"
#      }
#    }
#  }
#}

#resource "kubernetes_manifest" "rabbitmq_erl_inetrc" {
#  manifest = {
#    apiVersion = "v1"
#    kind       = "ConfigMap"
#    metadata = {
#      name      = "cm-rabbitmq-inetrc"
#      namespace = "queue"
#    }
#    data = {
#      erl_inetrc = <<-EOF
#        {inet6,true}.
#      EOF
#    }
#  }
#}

#resource "helm_release" "rabbitmq" {
#  name            = "rabbitmq"
#  namespace       = "queue"
#  repository      = "oci://registry-1.docker.io/cloudpirates"
#  chart           = "rabbitmq"
#  version         = "0.10.1"
#  cleanup_on_fail = true
#
#  values = [
#    yamlencode(yamldecode(templatefile("${path.module}/rabbitmq-values.yaml", {
#      ui_host              = "rabbitmq.vps.schwitzd.me"
#      myrabbit_password    = "${data.vault_generic_secret.rabbitmq_credentials.data.myrabbit}"
#      stock_write_password = "${data.vault_generic_secret.rabbitmq_credentials.data.stock-write}"
#      stock_read_password  = "${data.vault_generic_secret.rabbitmq_credentials.data.stock-read}"
#    })))
#  ]
#
#  depends_on = [
#    kubernetes_manifest.cert_rabbitmq_amqps,
#    kubernetes_manifest.rabbitmq_erl_inetrc
#  ]
#}
