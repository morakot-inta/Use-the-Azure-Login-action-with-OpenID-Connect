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

GITHUB_REPO="your-user/your-repo"   # YOUR repo: <username or org>/<repo>, exactly as on GitHub (case matters)
RG="rg-oidc-lab"                    # where the workflows deploy
LOCATION="southeastasia"
SUB_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "$SUB_ID $TENANT_ID"
```

Now ask GitHub what the **subject prefix** of your repo's tokens looks like (see [Lab 0](00-concepts.md#subject-formats-you-will-use)):

```bash
gh api "repos/$GITHUB_REPO/actions/oidc/customization/sub"
SUBJECT_PREFIX=$(gh api "repos/$GITHUB_REPO/actions/oidc/customization/sub" --jq .sub_claim_prefix)
echo "$SUBJECT_PREFIX"
```

| Output | Meaning |
|--------|---------|
| `repo:OWNER/REPO` | Classic format |
| `repo:OWNER@123/REPO@456` | **Immutable** format: owner ID and repo ID are part of the subject |

You can also look up the IDs yourself:
```bash
gh api "repos/$GITHUB_REPO" --jq '{owner: .owner.login, owner_id: .owner.id, owner_type: .owner.type, repo_id: .id}'
```

Every federated credential below uses `$SUBJECT_PREFIX`, so it matches your repo whichever format it uses.

### Save the variables (important)

Shell variables disappear when the terminal closes. **Azure Cloud Shell also ends your session after about 20 minutes
without use.** An empty variable causes confusing errors, for example `LocationRequired` or `ResourceGroupNotFound`.
Save the variables to a file:

```bash
cat > ~/oidc-lab.env <<EOF
GITHUB_REPO="$GITHUB_REPO"
SUBJECT_PREFIX="$SUBJECT_PREFIX"
RG="$RG"
ID_RG="rg-oidc-lab-identity"
LOCATION="$LOCATION"
SUB_ID="$SUB_ID"
TENANT_ID="$TENANT_ID"
EOF
cat ~/oidc-lab.env
```

**Every time you open a new terminal**, load them again and check that none is empty:

```bash
source ~/oidc-lab.env
for v in GITHUB_REPO SUBJECT_PREFIX RG ID_RG LOCATION SUB_ID TENANT_ID; do
  printf '%-15s %s\n' "$v" "${!v:-<EMPTY!>}"
done
```

> `SUBJECT_PREFIX` empty? `gh` is not logged in. Run `gh auth login`, or type the value yourself
> (see [Lab 0](00-concepts.md#subject-formats-you-will-use)).

Later steps add more values to this file with `echo 'NAME="value"' >> ~/oidc-lab.env`.

## Step 1: Resource group for the workload

```bash
az group create -n "$RG" -l "$LOCATION" -o table
```

The workflows will deploy here. The identity will get access to this resource group **only**.

## Step 2: App registration

```bash
APP_ID=$(az ad app create --display-name "gh-oidc-lab" --query appId -o tsv)
echo "APP_ID=$APP_ID"
echo "APP_ID=\"$APP_ID\"" >> ~/oidc-lab.env
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
echo "SP_OBJECT_ID=\"$SP_OBJECT_ID\"" >> ~/oidc-lab.env
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
  "subject": "$SUBJECT_PREFIX:ref:refs/heads/main",
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

> **Personal GitHub account (no organization)?** Type your **GitHub username** in *Organization*. If the portal asks
> for an **Organization ID** / **Repository ID**, use `owner_id` and `repo_id` from Step 0. A personal account's
> "organization ID" is your **user ID**.
>
> **Always compare** the *Subject identifier* that the portal shows with `$SUBJECT_PREFIX:ref:refs/heads/main`.
> If they differ, the login fails with `AADSTS700213`. If the portal can't build the right one, choose the
> **Other issuer** scenario and type the issuer and subject yourself.

| Field | Why |
|-------|-----|
| `issuer` | Accept tokens signed by GitHub only |
| `subject` | Accept only jobs from **this repo** on **this branch** |
| `audiences` | Accept only tokens that were requested *for* Azure token exchange |

## Step 6: Your turn: two more federated credentials

Create these yourself, using a JSON file or the portal:

| name | subject | Used in |
|------|---------|---------|
| `gh-env-production` | `$SUBJECT_PREFIX:environment:production` | Labs 4 and 6 |
| `gh-pull-request` | `$SUBJECT_PREFIX:pull_request` | Lab 7 |

<details><summary>Solution</summary>

```bash
for pair in "gh-env-production|environment:production" "gh-pull-request|pull_request"; do
  name=${pair%%|*}; entity=${pair#*|}
  az ad app federated-credential create --id "$APP_ID" -o none --parameters "{
    \"name\": \"$name\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"$SUBJECT_PREFIX:$entity\",
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
- [ ] 3 federated credentials, and each subject starts with your exact `$SUBJECT_PREFIX`
- [ ] Contributor on `rg-oidc-lab` only
- [ ] 3 secrets, 1 variable and the `production` environment exist in GitHub

Next: [Lab 2: Trust with a managed identity](02-setup-managed-identity.md)
