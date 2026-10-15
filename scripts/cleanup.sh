#!/usr/bin/env bash
# Deletes everything setup-oidc.sh created.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.env"

[[ -n "${SUBSCRIPTION_ID:-}" ]] && az account set --subscription "$SUBSCRIPTION_ID"

echo "This will delete:"
echo "  - Resource group:   $RESOURCE_GROUP"
echo "  - App registration: $APP_NAME"
echo "  - GitHub secrets/variable/environment in $GITHUB_REPO"
read -r -p "Continue? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 0

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv)
if [[ -n "$APP_ID" ]]; then
  # Delete role assignments before the SP disappears so they don't stay as "Unknown" identities.
  SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)
  if [[ -n "$SP_OBJECT_ID" ]]; then
    az role assignment delete --assignee "$SP_OBJECT_ID" --yes 2>/dev/null || true
  fi
  az ad app delete --id "$APP_ID"
  echo "Deleted app $APP_ID"
fi

if [[ "$(az group exists -n "$RESOURCE_GROUP")" == "true" ]]; then
  az group delete -n "$RESOURCE_GROUP" --yes --no-wait
  echo "Deleting resource group $RESOURCE_GROUP (running in background)"
fi

if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  for s in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
    gh secret delete "$s" --repo "$GITHUB_REPO" 2>/dev/null || true
  done
  gh variable delete AZURE_RESOURCE_GROUP --repo "$GITHUB_REPO" 2>/dev/null || true
  gh api --method DELETE "repos/$GITHUB_REPO/environments/$ENVIRONMENT_NAME" --silent 2>/dev/null || true
  echo "Removed GitHub secrets, variable and environment"
fi

echo "Cleanup complete."
