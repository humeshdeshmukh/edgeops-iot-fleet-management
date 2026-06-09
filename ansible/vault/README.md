# Using Ansible Vault for secrets

This folder contains guidance and examples for storing secrets used by the project.

Create a vault file:

```bash
ansible-vault create ansible/vault/secrets.yml
```

Edit a vault file:

```bash
ansible-vault edit ansible/vault/secrets.yml
```

Use the vault during playbook runs:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbooks/bootstrap_k3s.yml --ask-vault-pass
```

Recommended: use `ANSIBLE_VAULT_PASSWORD_FILE` or an external secrets backend in CI.
