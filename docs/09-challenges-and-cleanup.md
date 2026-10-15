# Lab 9: Challenges and cleanup

## Challenges (no step-by-step instructions)

1. **Least-privilege PRs:** Create a second identity (an app registration or a managed identity, you choose) with
   **Reader** on `rg-oidc-lab` and only a `pull_request` federated credential. Remove `gh-pull-request` from the main
   app. Change `05-pull-request.yml` to use a new secret `AZURE_READONLY_CLIENT_ID`. Then prove that
   `az storage account create` fails in a PR.

2. **Self-escalation attack (why Lab 2 used a separate resource group):** In a throwaway resource group, give a test
   managed identity **Contributor on the resource group that contains the identity itself**. From a workflow on `main`,
   use `az identity federated-credential create` to add a credential for `repo:OWNER/REPO:ref:refs/heads/evil`.
   Now push a branch called `evil` and log in from it. What does this teach you about where to put identities, and
   about who can write to them? Delete the test identity when you are done.

3. **Tags:** Add a federated credential for `ref:refs/tags/v1.0.0` and a workflow that runs on that tag.
   Why can't you write a single credential for `v*`? Find out about Entra **flexible federated identity credentials**
   (claims-matching expressions) and what they allow.

4. **Login without a subscription:** Remove the RBAC role and use `allow-no-subscriptions: true` to log in
   at tenant level only. What can you still do?

5. **Terraform / Bicep:** Use the same OIDC identity with Terraform (`ARM_USE_OIDC=true`, `ARM_CLIENT_ID`, ...) or
   `azure/arm-deploy`.

## Cleanup (by hand, in this order)

Set the variables again if your terminal was closed:

```bash
GITHUB_REPO="your-user/your-repo"
APP_ID=$(az ad app list --display-name gh-oidc-lab --query "[0].appId" -o tsv)
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
MI_PRINCIPAL_ID=$(az identity show -g rg-oidc-lab-identity -n id-gh-oidc-lab --query principalId -o tsv)
```

### 1. Role assignments first

If you delete an identity first, its role assignments stay behind as **"Identity not found"** entries in IAM.

```bash
az role assignment delete --assignee "$SP_OBJECT_ID" --yes
az role assignment delete --assignee "$MI_PRINCIPAL_ID" --yes
```

### 2. App registration

Deleting the app also deletes its service principal and its federated credentials.

```bash
az ad app delete --id "$APP_ID"
```

Portal: **App registrations → gh-oidc-lab → Delete**. The app stays in **Deleted applications** for 30 days and can be restored from there.

### 3. Resource groups

Deleting `rg-oidc-lab` also deletes the AKS cluster (Lab 8) and its node resource group `MC_rg-oidc-lab_...`.
Deleting `rg-oidc-lab-identity` also deletes the managed identity and its federated credentials.

```bash
az group delete -n rg-oidc-lab --yes --no-wait
az group delete -n rg-oidc-lab-identity --yes --no-wait
```

### 4. GitHub

**Settings → Secrets and variables → Actions**: delete the 4 secrets and the 2 variables. **Settings → Environments**: delete `production`.

```bash
for s in AZURE_CLIENT_ID AZURE_MI_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
  gh secret delete "$s" --repo "$GITHUB_REPO"
done
gh variable delete AZURE_RESOURCE_GROUP --repo "$GITHUB_REPO"
gh variable delete AKS_CLUSTER_NAME --repo "$GITHUB_REPO"
gh api --method DELETE "repos/$GITHUB_REPO/environments/production"
```

### Check that nothing is left

```bash
az group exists -n rg-oidc-lab                       # false (after a few minutes)
az group exists -n rg-oidc-lab-identity              # false
az ad app list --display-name gh-oidc-lab -o tsv     # empty
kubectl config delete-context aks-oidc-lab           # remove the local kubeconfig entry
```
