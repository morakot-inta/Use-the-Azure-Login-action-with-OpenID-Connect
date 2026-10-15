# Lab 1: Set up the trust between GitHub and Azure

You can use the **script** (fast) or run the **manual steps** (good for learning). Doing it manually once is a good idea.

## Option A: Script

```bash
cp scripts/config.env.example scripts/config.env
# edit scripts/config.env and set GITHUB_REPO=your-user/your-repo
az login
./scripts/setup-oidc.sh
```

The script is idempotent, so you can run it again safely. It also sets the GitHub secrets, the variable, and the environment for you.

## Option B: Manual with Azure CLI

```bash
GITHUB_REPO="your-user/your-repo"
RG="rg-oidc-lab"
LOCATION="southeastasia"
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
```

### 1. Create the app registration and service principal

```bash
APP_ID=$(az ad app create --display-name "gh-oidc-lab" --query appId -o tsv)
az ad sp create --id "$APP_ID"
SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
```

### 2. Create a resource group and give the service principal access to it only

```bash
az group create -n "$RG" -l "$LOCATION"
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"
```

> Scope the role to the resource group, **not** the whole subscription. That is least privilege.

### 3. Add federated credentials (one per subject)

```bash
az ad app federated-credential create --id "$APP_ID" --parameters "{
  \"name\": \"gh-branch-main\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"repo:$GITHUB_REPO:ref:refs/heads/main\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"
```

Repeat with these subjects:

| name | subject |
|------|---------|
| `gh-env-production` | `repo:$GITHUB_REPO:environment:production` |
| `gh-pull-request` | `repo:$GITHUB_REPO:pull_request` |

### 4. Save the identifiers in GitHub

```bash
gh secret set AZURE_CLIENT_ID       --repo "$GITHUB_REPO" --body "$APP_ID"
gh secret set AZURE_TENANT_ID       --repo "$GITHUB_REPO" --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --repo "$GITHUB_REPO" --body "$SUB_ID"
gh variable set AZURE_RESOURCE_GROUP --repo "$GITHUB_REPO" --body "$RG"
gh api --method PUT "repos/$GITHUB_REPO/environments/production"
```

## Option C: Azure portal (to see what the CLI did)

1. **Entra ID → App registrations → gh-oidc-lab → Certificates & secrets → Federated credentials**
2. You should see 3 credentials. Open one and check the *Issuer*, *Subject identifier*, and *Audience*.
3. Notice that the **Client secrets** tab is empty. That is the goal of OIDC.

## Checkpoint

- [ ] `az ad app federated-credential list --id $APP_ID -o table` shows 3 rows
- [ ] `az role assignment list --assignee $APP_ID --all -o table` shows Contributor on your RG
- [ ] `gh secret list` shows the 3 `AZURE_*` secrets

Next: [Lab 2: First login](02-first-login.md)
