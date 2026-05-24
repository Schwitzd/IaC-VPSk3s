terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "vps"
  insecure       = true
}

provider "vault" {
  address          = var.vault_url
  token            = var.vault_token
  skip_child_token = true
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "vps"
    insecure       = true
  }
}