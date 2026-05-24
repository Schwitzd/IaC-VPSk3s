# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Infrastructure as Code for the **VPS** K3s cluster — a single Netcup VPS node (`vps.schwitzd.me`) running a lightweight K3s cluster. Connected to the home network via WireGuard over IPv6. Uses the same dual-bootstrap pattern as IaC-HomeK3s: OpenTofu provisions essential resources, then Argo CD takes over GitOps reconciliation.

Services: RabbitMQ (message queue), OpenBao (secrets store), Traefik (using hostPorts, not LoadBalancer), ARK scraper stack.

## Tooling

- **OpenTofu** (not Terraform) — manages Kubernetes namespaces, secrets, RBAC
- **Ansible** — VPS provisioning, OS hardening, WireGuard, K3s post-config
- **K3s** — installed manually using the official script

## Common Commands

### Ansible

```bash
cd ansible

# Install dependencies
ansible-galaxy collection install -r requirements.yaml --force

# Initial VPS bootstrap (run once, in order)
ansible-playbook -i inventory.yaml playbooks/bootstrap-user.yaml -u root --ask-pass
ansible-playbook -i inventory.yaml playbooks/bootstrap-ssh.yaml -u root --ask-pass

# OS-level configuration (SSH hardening, WireGuard, nftables, apt)
ansible-playbook -i inventory.yaml playbooks/host.yaml

# K3s post-installation configuration
ansible-playbook -i inventory.yaml playbooks/k3s.yaml
```

### OpenTofu

```bash
cd terraform

tofu init
tofu plan --var-file=variables.tfvars
tofu apply --var-file=variables.tfvars
tofu apply --var-file=variables.tfvars --target=<resource>
```

### Vault bootstrap (separate module)

```bash
cd terraform/iac_vault
tofu init
tofu apply --var-file=variables.tfvars
```

### Register cluster with Argo CD

```bash
tofu apply --var-file=variables.tfvars --target=kubernetes_manifest.argocd_manager_sa
kubectl -n kube-system create token sa-argocd-manager --duration=8760h
```

## Architecture

### Terraform Directory (`terraform/`)

Minimal scope — one `.tf` file per concern:
- `main.tf` — namespace creation (pki, gateway, secrets, queue, stocks)
- `argocd.tf` — Argo CD ServiceAccount + ClusterRoleBinding for remote cluster management
- `cert-manager.tf` — Cloudflare API token secret
- `ark-scraper-collector.tf` — ARK scraper credentials
- `rabbitmq.tf` — RabbitMQ definitions secret
- `inputs.tf` / `locals.tf` — variables and namespace list

**Vault sub-module** (`terraform/iac_vault/`): Bootstrap Vault KV-v2 engine, policies, entities, and tokens. Uses modules from `github.com/Schwitzd/terraform-modules`. Applied independently before the main module.

**State**: Local state (`terraform.tfstate`) — no remote backend configured.

### Ansible Directory (`ansible/`)

- `inventory.yaml` — single host: `vps.schwitzd.me`
- `group_vars/all/all.yaml` — all variables (network, K3s CIDRs, WireGuard, nftables)
- `playbooks/` — lifecycle-ordered playbooks
- `playbooks/templates/` — Jinja2 templates for nftables and unattended-upgrades

### Provider Configuration

```hcl
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "vps"    # note: "vps" not "homefarm"
  insecure       = true
}
```

Vault provider uses `var.vault_url` / `var.vault_token` from `variables.tfvars` (gitignored).

### Secrets Pattern

- Secrets pulled from Vault at apply time via `data.vault_kv_secret_v2` data sources
- `data_wo` (write-only) used for ephemeral Kubernetes secrets — value never stored in state
- Kubernetes secret names follow `auth-*` prefix convention (e.g., `auth-api-cloudflare`, `auth-ark-rabbitmq`)
- `variables.tfvars` is gitignored

### Network

- WireGuard tunnel on `wg0`, port `51821`, using IPv6 ULA range `fd12:3456:789a:*`
- K3s dual-stack: cluster CIDR `fd42:10:42::/56,10.42.0.0/16`, service CIDR `fd42:10:43::/112,10.43.0.0/16`
- Traefik uses `hostPort` (not LoadBalancer) due to single-node VPS constraints
- nftables managed via Ansible Jinja2 template
