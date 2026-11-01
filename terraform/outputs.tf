output "eso_client_id" {
  description = "Universal Auth client ID of the ESO machine identity"
  value       = infisical_identity_universal_auth_client_secret.eso_vps.client_id
}

output "eso_client_secret" {
  description = "Universal Auth client secret of the ESO machine identity"
  value       = infisical_identity_universal_auth_client_secret.eso_vps.client_secret
  sensitive   = true
}
