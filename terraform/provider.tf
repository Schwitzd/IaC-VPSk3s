terraform {
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.20"
    }
  }
}

provider "infisical" {
  host = var.infisical_host
}
