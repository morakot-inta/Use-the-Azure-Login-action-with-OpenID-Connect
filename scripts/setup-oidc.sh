#!/usr/bin/env bash
# Creates the Azure side of the OIDC trust and configures the GitHub repo.
# Safe to re-run (idempotent).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/config.env"
[[ -f "$CONFIG" ]] || { echo "Missing $CONFIG. Copy config.env.example first."; exit 1; }
# shellcheck source=/dev/null
source "$CONFIG"

[[ "$GITHUB_REPO" == */* && "$GITHUB_REPO" != "your-user/oidc-lab" ]] \
  || { echo "Set GITHUB_REPO=OWNER/REPO in $CONFIG"; exit 1; }

ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "Azure context"
[[ -n "${SUBSCRIPTION_ID:-}" ]] && az account set --subscription "$SUBSCRIPTION_ID"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant:       $TENANT_ID"

step "App registration: $APP_NAME"
APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [[ -z "$APP_ID" ]]; then
  APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
  echo "Created app $APP_ID"
else
  echo "Exists: $APP_ID"
fi

step "Service principal"
SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)
if [[ -z "$SP_OBJECT_ID" ]]; then
  SP_OBJECT_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)
  echo "Created SP $SP_OBJECT_ID"
else
  echo "Exists: $SP_OBJECT_ID"
fi

step "Resource group: $RESOURCE_GROUP"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" -o none
SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

step "Role assignment: $ROLE on $SCOPE"
existing=$(az role assignment list --assignee "$SP_OBJECT_ID" --role "$ROLE" --scope "$SCOPE" --query "length(@)" -o tsv)
if [[ "$existing" == "0" ]]; then
  # A new service principal can take a few seconds to replicate, so retry.
  for i in {1..6}; do
    if az role assignment create --assignee-object-id "$SP_OBJECT_ID" \
         --assignee-principal-type ServicePrincipal --role "$ROLE" --scope "$SCOPE" -o none; then
      echo "Assigned"; break
    fi
    echo "Retrying in 10s ($i/6)..."; sleep 10
  done
else
  echo "Exists"
fi

add_fic() {
  local name="$1" subject="$2"
  local found
  found=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$name'] | length(@)" -o tsv)
  if [[ "$found" != "0" ]]; then
    echo "Exists: $name -> $subject"; return
  fi
  az ad app federated-credential create --id "$APP_ID" -o none --parameters "$(cat <<EOF
{
  "name": "$name",
  "issuer": "$ISSUER",
  "subject": "$subject",
  "audiences": ["$AUDIENCE"],
  "description": "GitHub Actions OIDC lab"
}
EOF
)"
  echo "Created: $name -> $subject"
}

step "Federated identity credentials"
add_fic "gh-branch-main"                "repo:$GITHUB_REPO:ref:refs/heads/main"
add_fic "gh-env-$ENVIRONMENT_NAME"      "repo:$GITHUB_REPO:environment:$ENVIRONMENT_NAME"
add_fic "gh-pull-request"               "repo:$GITHUB_REPO:pull_request"

step "GitHub repository configuration"
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh secret set AZURE_CLIENT_ID       --repo "$GITHUB_REPO" --body "$APP_ID"
  gh secret set AZURE_TENANT_ID       --repo "$GITHUB_REPO" --body "$TENANT_ID"
  gh secret set AZURE_SUBSCRIPTION_ID --repo "$GITHUB_REPO" --body "$SUBSCRIPTION_ID"
  gh variable set AZURE_RESOURCE_GROUP --repo "$GITHUB_REPO" --body "$RESOURCE_GROUP"
  gh api --method PUT "repos/$GITHUB_REPO/environments/$ENVIRONMENT_NAME" --silent
  echo "Secrets, variable and environment '$ENVIRONMENT_NAME' are configured."
else
  cat <<EOF
gh CLI is not available or not logged in. Add these in GitHub manually:
  Secrets:   AZURE_CLIENT_ID=$APP_ID
             AZURE_TENANT_ID=$TENANT_ID
             AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
  Variable:  AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
  Environment: $ENVIRONMENT_NAME
EOF
fi

step "Done"
echo "Next: gh workflow run 01-login-oidc.yml --repo $GITHUB_REPO --ref main"
