# Existing project, adopted with an import block (see var.infisical_project_id).
import {
  to = infisical_project.vps
  id = var.infisical_project_id
}

resource "infisical_project" "vps" {
  name = "VPS"
  slug = "vps-nu8-u"
  type = "secret-manager"
}
