# Lab 3: First login with `azure/login`

Workflow: [`.github/workflows/01-login-oidc.yml`](../.github/workflows/01-login-oidc.yml)

## Read the workflow first

Two parts make OIDC work:

```yaml
permissions:
  id-token: write   # allows the job to request a GitHub OIDC token
  contents: read    # once you set any permission, the others default to none

steps:
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets[inputs.identity == 'managed-identity' && 'AZURE_MI_CLIENT_ID' || 'AZURE_CLIENT_ID'] }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

- There is no `client-secret` and no `creds:` input. When `azure/login` gets only a client ID and a tenant ID, it uses OIDC.
- The `identity` input chooses the client ID. **That is the only difference** between the app registration and the
  managed identity.
- `secrets[...]` looks up the secret *by name*. If that secret is missing, `client-id` is empty and the login fails with
  a clear error, instead of quietly signing in as the other identity.

## Run it with each identity

```bash
gh workflow run 01-login-oidc.yml --ref main -f identity=app-registration
gh workflow run 01-login-oidc.yml --ref main -f identity=managed-identity
gh run list --workflow 01-login-oidc.yml
gh run view <run-id> --log
```

Or use **Actions → 01 - Azure Login (OIDC) → Run workflow** and choose the identity.

## What to look for in the log

1. In the `azure/login` step: `Federated token details` shows the issuer and subject that were sent to Entra ID.
2. `az account show`: `user.name` is the client ID of the identity you chose, and `user.type` is `servicePrincipal` for **both**.
3. `az group show` works on `rg-oidc-lab`.
4. `az group list` shows **only** `rg-oidc-lab`, because RBAC is scoped to it. The managed identity does not even see
   `rg-oidc-lab-identity`.

## Questions

1. Why does `az group list` return only one group, even if your subscription has many?
2. Both runs sent the same subject. How did Entra ID know which identity's federated credentials to check?
3. Remove the managed identity's `gh-branch-main` credential and run again with `managed-identity`. What happens?
   (Then create it again as in Lab 2, Step 4.)

Next: [Lab 4: Inspect the token](04-inspect-token.md)
