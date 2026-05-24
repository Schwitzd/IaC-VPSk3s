# IaC-VPS

This repository documents and automates the setup of my VPS using **Ansible** and **OpenTofu**. It is part of my home infrastructure and acts as the always-on, internet-facing extension of it.

The VPS currently runs the following services:

* **RabbitMQ** – Used as a buffer for messages produced by various services. Messages are queued here and later consumed by my home “farm” cluster, which is not always powered on.
* **OpenBao** – The central secrets store for the entire infrastructure, used by all K3s clusters as well as the VPS itself.

The VPS is connected to my [home network](https://github.com/Schwitzd/IaC-HomeRouter) via a **WireGuard** tunnel over IPv6, using a [Route64 tunnel broker](https://www.schwitzd.me/posts/mikrotik-tunnelbroker-with-route64/).

The underlying host is a small Netcup instance, the [VPS nano G11s 6M](https://www.netcup.com/de/server/vps/vps-nano-g11s-6m), with 2 GiB of RAM.

## Requirements

Install the needed Ansible roles and collections:

```sh
ansible-galaxy collection install -r requirements.yaml --force
ansible-galaxy role install -r requirements.yaml --force
```

### Local vault

This project uses a dual-vault setup. Primitive bootstrap secrets are stored in a local Vault instance on my laptop, while all workload and runtime secrets are stored in the central OpenBao instance.

1. Initialize OpenTofu for Vault in your project directory:

    ```sh
    cd terraform
    tofu init
    ```

1. Create the Vault space:

    ```sh
      cd iac_vault
      tofu init
      tofu apply --var-file=variables.tfvars
    ```

1. Get the Vault token:

    ```sh
        tofu output client_token
    ```

## Bootstrap

Bootstrap process will:

1. Create a dedicated VPS user
1. Provision and configure SSH public key authentication for the VPS user

```sh
# Bootstrap the VPS user
ansible-playbook -i inventory.yaml playbooks/bootstrap-user.yaml -u root --ask-pass -e 'ansible_ssh_common_args="-o PubkeyAuthentication=no -o PreferredAuthentications=password -o IdentitiesOnly=yes"'
# Boostrap SSH keys
ansible-playbook -i inventory.yaml playbooks/bootstrap-ssh.yaml -u root --ask-pass -e 'ansible_ssh_common_args="-o PubkeyAuthentication=no -o PreferredAuthentications=password -o IdentitiesOnly=yes"'
```

## Host

Provision host-level configuration (SSH hardening, base services, etc...):

```sh
ansible-playbook -i inventory.yaml playbooks/host.yaml
```

### Wireguard

After the `host` playbook has successfully created the WireGuard interface, retrieve the VPS public key with:

```sh
sudo wg show wg0 public-key
```

This key is required to configure the corresponding peer on the MikroTik router.

## K3s

Create the installation config file in `/etc/rancher/k3s/config.yaml`:

```yaml
write-kubeconfig-mode: "644"
disable-cloud-controller: true
disable:
  - servicelb
  - coredns
  - traefik
node-ip: 
  - "2a03:4000:6:d90d:3825:8eff:fe0d:7047"
  - "188.68.51.201"
node-external-ip:
  - "2a03:4000:6:d90d:3825:8eff:fe0d:7047"
  - "188.68.51.201"
tls-san:
  - "vps.schwitzd.me"
secrets-encryption: true
cluster-cidr: "fd42:10:42::/56,10.42.0.0/16"
service-cidr: "fd42:10:43::/112,10.43.0.0/16"
disable-network-policy: true
kube-proxy-arg:
  - "proxy-mode=nftables"
```

Proceed with the installation:

```sh
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.34.4+k3s1" sh
```

Once Kubernetes is installed:

```sh
ansible-playbook -i inventory.yaml playbooks/k3s.yaml
```

### Argo CD

Because the VPS only has 2 GiB of RAM, it is intentionally kept lightweight and reserved for edge services. Running Argo CD directly on the VPS would provide little benefit while consuming resources better used by workloads. Instead, the VPS K3s cluster is registered as a remote cluster in the Argo CD instance running on the farm cluster. This allows the farm to act as a centralized GitOps control plane while keeping the VPS minimal.

Argo CD authenticates to the VPS using a dedicated ServiceAccount (`sa-argocd-manager`) and a long-lived ServiceAccount token generated explicitly for this purpose:

```sh
# Create the SA and associated RBAC
tofu apply --var-file=variables.tfvars --target=kubernetes_manifest.argocd_manager_sa --target=kubernetes_manifest.argocd_manager_crb

# Mint the token
kubectl -n kube-system create token sa-argocd-manager --duration=8760h
```

The token is generated manually, stored in Argo CD as part of the cluster registration, and rotated manually based on a scheduled reminder.

### Traefik

This cluster does not use a Kubernetes LoadBalancer, as it runs on a single VPS where the node itself already owns the public IP. Instead, Traefik is configured with `hostPorts` and binds directly to the node's network interfaces on ports 80 and 443. Incoming traffic follows a simple and explicit path, avoiding unnecessary load-balancer layers:

```mermaid
flowchart LR
    Internet[Internet]

    LoadBalancer["Kubernetes LoadBalancer<br/>(not used)"]
    Traefik["Traefik<br/>hostPorts :80 / :443"]
    Service["Kubernetes Service<br/>ClusterIP"]
    Pod[Application Pod]
    Internet --> Traefik --> Service --> Pod
    Internet -.-> LoadBalancer
    LoadBalancer -.-> Traefik
```

Traefik example of port configuration:

```yaml
ports:
  websecure:
    port: 443
    hostPort: 443
    expose:
      default: true
    exposedPort: 443
```

## To Do

- Move to Gateway API with HTTPRoute
