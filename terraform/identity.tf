# Machine identity used by External Secrets Operator on the VPS cluster.
resource "infisical_identity" "eso_vps" {
  name   = "eso-vps"
  role   = "no-access"
  org_id = var.infisical_org_id
}

resource "infisical_identity_universal_auth" "eso_vps" {
  identity_id = infisical_identity.eso_vps.id

  # Paid plans only: leave var.trusted_ips unset on the free tier
  access_token_trusted_ips  = var.trusted_ips == null ? null : [for ip in var.trusted_ips : { ip_address = ip }]
  client_secret_trusted_ips = var.trusted_ips == null ? null : [for ip in var.trusted_ips : { ip_address = ip }]
}

resource "infisical_identity_universal_auth_client_secret" "eso_vps" {
  identity_id = infisical_identity.eso_vps.id
  description = "External Secrets Operator (VPS cluster)"

  depends_on = [infisical_identity_universal_auth.eso_vps]
}

# Built-in read-only role: custom roles (path/env scoping) and IP allow-listing
# are paid features, so the identity gets the project-wide "viewer" role instead.
resource "infisical_project_identity" "eso_vps" {
  project_id  = infisical_project.vps.id
  identity_id = infisical_identity.eso_vps.id

  roles = [
    {
      role_slug = "viewer"
    }
  ]
}
