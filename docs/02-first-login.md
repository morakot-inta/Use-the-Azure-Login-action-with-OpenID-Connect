# Lab 2: First login with `azure/login`

Workflow: [`.github/workflows/01-login-oidc.yml`](../.github/workflows/01-login-oidc.yml)

## Read the workflow first

Two parts make OIDC work:

```yaml
permissions:
  id-token: write   # allows the job to request a GitHub OIDC token
  contents: read    # needed by actions/checkout once you set any permission

steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

There is no `client-secret` and no `creds:` input. When `azure/login` gets only a client ID and a tenant ID,
it uses OIDC.

## Run it

```bash
gh workflow run 01-login-oidc.yml --ref main
gh run watch
```

Or use **Actions → 01 - Azure Login (OIDC) → Run workflow** in the GitHub UI.

## What to look for in the log

1. In the `azure/login` step: `Federated token details` shows the issuer and subject that were sent to Entra ID.
2. `az account show` shows `"type": "servicePrincipal"` and your app's client ID.
3. `az group show` works on your lab resource group.
4. `az group list` lists **only** your lab resource group, because RBAC is scoped to it.

## Questions

1. Why does `az group list` return only one group, even if your subscription has many?
2. What subject was sent? Which federated credential matched it?

Next: [Lab 3: Inspect the token](03-inspect-token.md)
