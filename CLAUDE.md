# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Infrastructure as Code for the **VPS** K3s cluster — a single Netcup VPS node (`vps.schwitzd.me`, 2 GiB RAM) running a lightweight K3s cluster. Connected to the home network via WireGuard over IPv6. Ansible provisions the host and K3s, then bootstraps FluxCD, which reconciles the cluster from the [GitOps-VPS](https://github.com/Schwitzd/GitOps-VPS) repository. Secrets in that repo are encrypted with SOPS (age).

Services: RabbitMQ (message queue), Traefik (using hostPorts, not LoadBalancer), ARK scraper stack.

## Tooling

- **Ansible** — VPS provisioning, OS hardening, WireGuard, K3s post-config, Flux bootstrap
- **K3s** — installed manually using the official script
- **FluxCD** — GitOps controller (source, kustomize and helm controllers only, to save RAM)
- **SOPS + age** — manifest secret encryption, decrypted in-cluster by Flux using the `sops-age` Secret

## Common Commands

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

# Flux bootstrap (needs GITHUB_TOKEN env var and the age key on the control machine)
ansible-playbook -i inventory.yaml playbooks/bootstrap-flux.yaml
```

## Architecture

### Ansible Directory (`ansible/`)

- `inventory.yaml` — single host: `vps.schwitzd.me`
- `group_vars/all/all.yaml` — all variables (network, K3s CIDRs, WireGuard, nftables, Flux)
- `playbooks/` — lifecycle-ordered playbooks
- `playbooks/templates/` — Jinja2 templates for K3s config, nftables and unattended-upgrades

### GitOps

- Flux is bootstrapped by `playbooks/bootstrap-flux.yaml` against `Schwitzd/GitOps-VPS`, branch `main`, path `clusters/vps`
- Workloads, namespaces and encrypted secrets live in `GitOps-VPS`, not in this repository
- The age private key is never stored in git; it is read from `sops_age_key_file` on the control machine and loaded into the cluster as `flux-system/sops-age`

### Network

- WireGuard tunnel on `wg0`, port `51821`, using IPv6 ULA range `fd12:3456:789a:*`
- K3s dual-stack: cluster CIDR `fd42:10:42::/56,10.42.0.0/16`, service CIDR `fd42:10:43::/112,10.43.0.0/16`
- Traefik uses `hostPort` (not LoadBalancer) due to single-node VPS constraints
- nftables managed via Ansible Jinja2 template
