# Lab 1: Trust with an app registration

In this lab you create, one at a time, every object that `azure/login` needs. After each step you **check** what you
created. Each step shows the Azure CLI command and the matching place in the Azure portal. Use either one.

> No permission to create app registrations? Skip to [Lab 2](02-setup-managed-identity.md) and use a managed identity
> for every lab.

## Step 0: Variables

Open a terminal (or [Cloud Shell](https://shell.azure.com)) and keep it open for Labs 1 and 2.

```bash
az login
az account show -o table          # is this the subscription you want? If not: az account set -s <id>

GITHUB_REPO="your-user/your-repo"   # YOUR fork, exactly as it appears on GitHub (case matters)
RG="rg-oidc-lab"                    # where the workflows deploy
LOCATION="southeastasia"
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "$SUB_ID $TENANT_ID"
```

## Step 1: Resource group for the workload

```bash
az group create -n "$RG" -l "$LOCATION" -o table
```

The workflows will deploy here. The identity will get access to this resource group **only**.

## Step 2: App registration

```bash
APP_ID=$(az ad app create --display-name "gh-oidc-lab" --query appId -o tsv)
echo "APP_ID=$APP_ID"
```

Portal: **Microsoft Entra ID → App registrations → New registration** → name `gh-oidc-lab` → **Register**.

Check it:
```bash
az ad app show --id "$APP_ID" --query "{name:displayName, appId:appId, objectId:id}" -o table
```

> **Two IDs, don't mix them up.** `appId` (*Application (client) ID*) is what `azure/login` needs.
> `id` (*Object ID*) is the ID of the directory object. Using the Object ID as `client-id` is a very common mistake
> (Lab 5, scenario 3).

## Step 3: Service principal

An app registration is only a *definition*. To give it Azure roles, your tenant needs a **service principal** (an instance) of it.

```bash
az ad sp create --id "$APP_ID" -o none
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
echo "SP_OBJECT_ID=$SP_OBJECT_ID"
```

Portal: the portal creates it for you when you register an app. You can find it under
**Entra ID → Enterprise applications → gh-oidc-lab**.

> **Question:** The SP's object ID is different from the app's object ID. Why?

## Step 4: Role assignment (RBAC)

```bash
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG" -o table
```

Portal: **Resource groups → rg-oidc-lab → Access control (IAM) → Add role assignment → Contributor →
Members: User, group, or service principal → gh-oidc-lab**.

Check it:
```bash
az role assignment list --assignee "$SP_OBJECT_ID" --all -o table
```

> We use `--assignee-object-id` + `--assignee-principal-type` instead of `--assignee` because a brand-new SP may not
> have replicated in Entra ID yet. If you get `PrincipalNotFound`, wait 30 seconds and try again.

At this point the app has permissions, but **nothing can sign in as it**: it has no secret and no federated credential.

## Step 5: Federated credential for the `main` branch

Write the trust rule as a file so that you can read every field:

```bash
cat > fic-main.json <<EOF
{
  "name": "gh-branch-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:$GITHUB_REPO:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "GitHub Actions jobs on main"
}
EOF
cat fic-main.json
az ad app federated-credential create --id "$APP_ID" --parameters @fic-main.json -o table
```

Portal: **App registrations → gh-oidc-lab → Certificates & secrets → Federated credentials → Add credential** →
scenario **GitHub Actions deploying Azure resources** → fill in Organization, Repository, Entity type **Branch**, Branch **main**.
Look at the *Subject identifier* that the portal builds for you.

| Field | Why |
|-------|-----|
| `issuer` | Accept tokens signed by GitHub only |
| `subject` | Accept only jobs from **this repo** on **this branch** |
| `audiences` | Accept only tokens that were requested *for* Azure token exchange |

## Step 6: Your turn: two more federated credentials

Create these yourself, using a JSON file or the portal:

| name | subject | Used in |
|------|---------|---------|
| `gh-env-production` | `repo:$GITHUB_REPO:environment:production` | Labs 4 and 6 |
| `gh-pull-request` | `repo:$GITHUB_REPO:pull_request` | Lab 7 |

<details><summary>Solution</summary>

```bash
for pair in "gh-env-production|environment:production" "gh-pull-request|pull_request"; do
  name=${pair%%|*}; entity=${pair#*|}
  az ad app federated-credential create --id "$APP_ID" -o none --parameters "{
    \"name\": \"$name\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_REPO:$entity\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
done
```
</details>

Check it:
```bash
az ad app federated-credential list --id "$APP_ID" --query "[].{name:name, subject:subject}" -o table
```

## Step 7: Configure GitHub

GitHub: **your repo → Settings**

1. **Environments → New environment** → `production` (leave the protection rules empty for now; you add them in Lab 6)
2. **Secrets and variables → Actions → Secrets → New repository secret**:
   - `AZURE_CLIENT_ID` = `$APP_ID`
   - `AZURE_TENANT_ID` = `$TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID` = `$SUB_ID`
3. **Secrets and variables → Actions → Variables → New repository variable**: `AZURE_RESOURCE_GROUP` = `rg-oidc-lab`

Or with the GitHub CLI:
```bash
gh api --method PUT "repos/$GITHUB_REPO/environments/production" --silent
gh secret set AZURE_CLIENT_ID       --repo "$GITHUB_REPO" --body "$APP_ID"
gh secret set AZURE_TENANT_ID       --repo "$GITHUB_REPO" --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --repo "$GITHUB_REPO" --body "$SUB_ID"
gh variable set AZURE_RESOURCE_GROUP --repo "$GITHUB_REPO" --body "$RG"
```

## Checkpoint

- [ ] App **Certificates & secrets → Client secrets** is **empty**. That is the goal of OIDC.
- [ ] 3 federated credentials, and each subject contains your exact `OWNER/REPO`
- [ ] Contributor on `rg-oidc-lab` only
- [ ] 3 secrets, 1 variable and the `production` environment exist in GitHub

Next: [Lab 2: Trust with a managed identity](02-setup-managed-identity.md)
