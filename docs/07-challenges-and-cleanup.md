# Lab 7: Challenges and cleanup

## Challenges (no step-by-step instructions)

1. **Least-privilege PRs:** Create a second app registration `gh-oidc-lab-readonly` with **Reader** on the RG and a
   `pull_request` federated credential only. Remove `gh-pull-request` from the main app. Change `05-pull-request.yml`
   to use a new secret `AZURE_CLIENT_ID_READONLY`. Then prove that `az storage account create` fails in a PR.

2. **User-assigned managed identity instead of an app registration:** Create a UAMI
   (`az identity create`), and add a federated credential to it with
   `az identity federated-credential create --identity-name ... --issuer ... --subject ... --audiences api://AzureADTokenExchange`.
   Use its `clientId` in `azure/login`. What is different? (Hint: no Entra app registration is needed, and the identity
   is an Azure resource that has its own lifecycle and RBAC.)

3. **Tags:** Add a federated credential for `ref:refs/tags/v1.0.0` and a workflow that runs on that tag.
   Why can't you write a single credential for `v*`? Find out about Entra **flexible federated identity credentials**
   (claims-matching expressions) and what they allow.

4. **Login without a subscription:** Remove the subscription's RBAC and use `allow-no-subscriptions: true` to log in
   at tenant level only. What can you still do?

5. **Terraform / Bicep:** Use the same OIDC identity with Terraform (`ARM_USE_OIDC=true`, `ARM_CLIENT_ID`, ...) or
   `azure/arm-deploy`.

## Cleanup

```bash
./scripts/cleanup.sh
```

This deletes:
- the resource group (and the storage account in it)
- the app registration (and with it the service principal, federated credentials and role assignments)
- the GitHub secrets, the variable and the `production` environment

Check that nothing is left:
```bash
az group exists -n rg-oidc-lab          # false
az ad app list --display-name gh-oidc-lab -o tsv   # empty
```
