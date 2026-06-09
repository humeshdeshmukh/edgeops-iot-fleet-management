# Project 18: EdgeOps - IoT Fleet Management

Minimal scaffold for an edge GitOps deployment and observability reference.

Quick actions

Bootstrap a store node with Ansible:

```bash
# from repository root
ansible-playbook -i ansible/inventory.ini ansible/playbooks/bootstrap_k3s.yml
ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure_wireguard.yml
```

Inventory and group variables

- Edit `ansible/inventory.ini` for your hosts or provide a dynamic inventory.
- Customize group variables in `ansible/group_vars/edge.yml` (K3s version, WireGuard peer key, remote write endpoint).

Run the example Nomad job locally (if running Nomad agent):

```bash
nomad job run nomad/jobs/store_app.nomad
```

Apply ArgoCD application manifests to central ArgoCD:

```bash
kubectl apply -f argocd-edge/pull-agent-config.yaml -n argocd
kubectl apply -f argocd-edge/application.yaml -n argocd
```

Start Prometheus with the provided federation config (example):

```bash
docker run --rm -p 9090:9090 -v $(pwd)/monitoring/prometheus-federation.yaml:/etc/prometheus/prometheus.yml prom/prometheus
```

Files added

- [ansible/playbooks/bootstrap_k3s.yml](18-edgeops-iot-fleet-management/ansible/playbooks/bootstrap_k3s.yml)
- [ansible/playbooks/configure_wireguard.yml](18-edgeops-iot-fleet-management/ansible/playbooks/configure_wireguard.yml)
- [nomad/jobs/store_app.nomad](18-edgeops-iot-fleet-management/nomad/jobs/store_app.nomad)
- [argocd-edge/pull-agent-config.yaml](18-edgeops-iot-fleet-management/argocd-edge/pull-agent-config.yaml)
- [argocd-edge/application.yaml](18-edgeops-iot-fleet-management/argocd-edge/application.yaml)
- [monitoring/prometheus-federation.yaml](18-edgeops-iot-fleet-management/monitoring/prometheus-federation.yaml)

Notes

This scaffold provides practical, minimal examples to get started. I can expand any of the playbooks, add inventory templates, or create Helm charts for the store app next.

Completed: Helm chart, CI workflow, ArgoCD ApplicationSet, Prometheus remote_write buffering/TLS placeholders, Ansible Vault docs, and WireGuard keygen script.

Runbook (quick end-to-end):

1. Edit `ansible/inventory.ini` and `ansible/group_vars/edge.yml`.
2. Create secrets: `ansible-vault create ansible/vault/secrets.yml` and populate keys (WireGuard, Prometheus token).
3. Bootstrap edge node: `ansible-playbook -i ansible/inventory.ini ansible/playbooks/bootstrap_k3s.yml --ask-vault-pass`.
4. Configure WireGuard: `ansible-playbook -i ansible/inventory.ini ansible/playbooks/configure_wireguard.yml --ask-vault-pass`.
5. Build/push container and lint chart via GitHub Actions (CI).
6. Apply ArgoCD manifests: `kubectl apply -f argocd-edge/ -n argocd`.
7. Ensure Prometheus on edge has `prometheus-federation.yaml` and CA/token mounted (via Vault or CSI).

