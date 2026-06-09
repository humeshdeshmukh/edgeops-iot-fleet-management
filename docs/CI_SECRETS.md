# CI Secrets and Vault integration

Set these repository secrets in GitHub (Settings → Secrets):

- `REGISTRY_URL` — Container registry host (e.g., ghcr.io/your-org)
- `REGISTRY_USERNAME` — Registry user
- `REGISTRY_PASSWORD` — Registry password or token
- `CHART_REGISTRY` — OCI chart registry (e.g., ghcr.io/your-org)
- `CHART_USERNAME` / `CHART_PASSWORD` — Chart registry creds
- `VAULT_ADDR` — HashiCorp Vault URL (for `ci-vault.yml`)
- `VAULT_TOKEN` — Vault token with read access to secrets used in CI

Notes:
- Prefer using short-lived tokens or OIDC-based workflows instead of long-lived tokens.
- Use GitHub Actions environment protection rules for high-privilege workflows.
