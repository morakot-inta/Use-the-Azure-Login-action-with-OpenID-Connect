# Lab 2: Trust with a user-assigned managed identity

Now you build the same trust with a **user-assigned managed identity (UAMI)**. There is no Entra app registration,
and a managed identity can **never** have a client secret. The workflows only need a different `client-id`.

Use the same terminal and variables as in Lab 1 (`GITHUB_REPO`, `SUBJECT_PREFIX`, `RG`, `LOCATION`, `SUB_ID`, `TENANT_ID`).
If you skipped Lab 1, run its [Step 0](01-setup-app-registration.md#step-0-variables) and
[Step 1](01-setup-app-registration.md#step-1-resource-group-for-the-workload) first.

## Step 1: A separate resource group for the identity

```bash
ID_RG="rg-oidc-lab-identity"
az group create -n "$ID_RG" -l "$LOCATION" -o table
```

**Why not put the identity in `rg-oidc-lab`?** The identity gets **Contributor** on `rg-oidc-lab`. Contributor can
write `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials`. If the identity lived in the
same resource group, a workflow could **add new federated credentials to its own identity** (for example, for any
branch) and so escape your trust rules. Keep identities away from the resources they manage. You try this attack in
Lab 10, Challenge 2.

## Step 2: Create the managed identity

```bash
az identity create -g "$ID_RG" -n "id-gh-oidc-lab" -l "$LOCATION" -o json
MI_CLIENT_ID=$(az identity show -g "$ID_RG" -n id-gh-oidc-lab --query clientId -o tsv)
MI_PRINCIPAL_ID=$(az identity show -g "$ID_RG" -n id-gh-oidc-lab --query principalId -o tsv)
echo "MI_CLIENT_ID=$MI_CLIENT_ID  MI_PRINCIPAL_ID=$MI_PRINCIPAL_ID"
```

Portal: **Managed Identities → Create** → resource group `rg-oidc-lab-identity`, name `id-gh-oidc-lab`.

| Output field | Used for |
|--------------|----------|
| `clientId` | `client-id` in `azure/login` |
| `principalId` | The object ID of its service principal, used for role assignments |
| `id` | The Azure resource ID. It's an ARM resource, unlike the app registration |

Compare it with the app registration:
```bash
az ad sp show --id "$MI_CLIENT_ID" --query "{name:displayName, type:servicePrincipalType}" -o table   # ManagedIdentity
az ad app show --id "$MI_CLIENT_ID"   # fails: there is no app registration behind a managed identity
```

## Step 3: Role assignment

```bash
az role assignment create \
  --assignee-object-id "$MI_PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG" -o table
```

Portal: **Resource groups → rg-oidc-lab → Access control (IAM) → Add role assignment → Contributor →
Members: Managed identity → User-assigned managed identity → id-gh-oidc-lab**.

Check that it has **no** role on its own resource group:
```bash
az role assignment list --assignee "$MI_PRINCIPAL_ID" --all --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

## Step 4: Federated credential for `main`

With a managed identity, the federated credential is a child resource of the identity, so you create it with
`az identity` instead of `az ad app`:

```bash
az identity federated-credential create \
  --resource-group "$ID_RG" --identity-name id-gh-oidc-lab \
  --name gh-branch-main \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "$SUBJECT_PREFIX:ref:refs/heads/main" \
  --audiences "api://AzureADTokenExchange" -o table
```

Portal: **Managed Identities → id-gh-oidc-lab → Settings → Federated credentials → Add credential** →
scenario **GitHub Actions deploying Azure resources** → Organization = your GitHub username or org (and its ID if asked), Entity **Branch**, Branch **main**.
Check that the subject it builds equals `$SUBJECT_PREFIX:ref:refs/heads/main`.

## Step 5: Your turn: the environment credential

Create `gh-env-production` for subject `$SUBJECT_PREFIX:environment:production`.

<details><summary>Solution</summary>

```bash
az identity federated-credential create \
  --resource-group "$ID_RG" --identity-name id-gh-oidc-lab \
  --name gh-env-production \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "$SUBJECT_PREFIX:environment:production" \
  --audiences "api://AzureADTokenExchange" -o none
```
</details>

Check it:
```bash
az identity federated-credential list -g "$ID_RG" --identity-name id-gh-oidc-lab \
  --query "[].{name:name, subject:subject}" -o table
```

We do **not** add a `pull_request` credential to the managed identity. In Lab 7, PRs use only the app registration.

## Step 6: Configure GitHub

Add one more repository secret (the tenant ID, subscription ID and resource group are the same as in Lab 1):

- `AZURE_MI_CLIENT_ID` = `$MI_CLIENT_ID`

```bash
gh secret set AZURE_MI_CLIENT_ID --repo "$GITHUB_REPO" --body "$MI_CLIENT_ID"
```

Skipped Lab 1? Also set `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, the `AZURE_RESOURCE_GROUP` variable and the
`production` environment as described in [Lab 1, Step 7](01-setup-app-registration.md#step-7-configure-github).
Always choose `managed-identity` when you run a workflow.

## Checkpoint

- [ ] The identity is in `rg-oidc-lab-identity`, and it has Contributor on `rg-oidc-lab` only
- [ ] 2 federated credentials (`main`, `environment:production`)
- [ ] `AZURE_MI_CLIENT_ID` secret exists

## Questions

1. Which identity type would you choose if your team **cannot** get Entra app registration permission?
2. What happens to the managed identity, and to any workflow that uses it, if someone deletes `rg-oidc-lab-identity`?
3. Who in your organization can change the trust rules of each identity type?

Next: [Lab 3: First login](03-first-login.md)
