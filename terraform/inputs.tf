variable "infisical_host" {
  description = "The Infisical host URL"
  type        = string
  default     = "https://eu.infisical.com"
}

variable "infisical_org_id" {
  description = "The Infisical organization ID the machine identity is created in"
  type        = string
}

variable "infisical_project_id" {
  description = "ID of the existing Infisical project, used only to import it into state"
  type        = string
}

variable "trusted_ips" {
  description = "IPs or CIDR ranges allowed to use the client secret and tokens (paid plans only, null = unrestricted)"
  type        = list(string)
  default     = null
}
