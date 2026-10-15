#!/usr/bin/env bash
# Creates the AKS cluster for Lab 8 and gives YOU (the signed-in user) cluster admin.
# It does NOT give the GitHub identities any access. You do that by hand in Lab 8, Step 3.
#
# Usage:  ./scripts/create-aks.sh
# Override defaults with env vars, for example:  NODE_SIZE=Standard_D2s_v5 ./scripts/create-aks.sh
set -euo pipefail

RG="${RG:-rg-oidc-lab}"
AKS_NAME="${AKS_NAME:-aks-oidc-lab}"
NODE_SIZE="${NODE_SIZE:-Standard_B2s}"   # cheapest size AKS allows for a system pool; change it if you have no quota
NODE_COUNT="${NODE_COUNT:-1}"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "Checking prerequisites"
az group show -n "$RG" -o none || { echo "Resource group $RG not found. Do Lab 1, Step 1 first."; exit 1; }
LOCATION=$(az group show -n "$RG" --query location -o tsv)
az provider register --namespace Microsoft.ContainerService -o none

step "Creating AKS cluster $AKS_NAME in $RG ($LOCATION). This takes about 5-10 minutes."
if az aks show -g "$RG" -n "$AKS_NAME" -o none 2>/dev/null; then
  echo "Cluster already exists, skipping create."
else
  # --enable-aad + --enable-azure-rbac : Kubernetes logins use Entra ID, and Kubernetes permissions are Azure role assignments
  # --disable-local-accounts           : no static admin kubeconfig, so `get-credentials --admin` is blocked.
  #                                      Without this, anyone with Contributor on the RG could become cluster admin.
  az aks create -g "$RG" -n "$AKS_NAME" \
    --tier free \
    --node-count "$NODE_COUNT" --node-vm-size "$NODE_SIZE" \
    --enable-aad --enable-azure-rbac --disable-local-accounts \
    --generate-ssh-keys \
    -o none
fi
AKS_ID=$(az aks show -g "$RG" -n "$AKS_NAME" --query id -o tsv)

step "Giving you (the signed-in user) cluster admin on Kubernetes"
ME=$(az ad signed-in-user show --query id -o tsv)
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Azure Kubernetes Service RBAC Cluster Admin" --scope "$AKS_ID" -o none \
  || echo "Could not assign (maybe it already exists). Check: az role assignment list --scope $AKS_ID -o table"
echo "Assigned. Kubernetes RBAC role assignments can take a few minutes to start working."

step "Installing kubectl + kubelogin if needed"
if ! command -v kubelogin >/dev/null || ! command -v kubectl >/dev/null; then
  echo "Install them once, then run the script again:"
  echo "  az aks install-cli        (or on macOS: brew install kubectl Azure/kubelogin/kubelogin)"
  exit 1
fi

step "Connecting kubectl"
az aks get-credentials -g "$RG" -n "$AKS_NAME" --overwrite-existing
kubelogin convert-kubeconfig -l azurecli   # use your `az login` session for Kubernetes tokens
kubectl get nodes -o wide || echo "Forbidden? Wait 2-5 minutes for the role assignment, then run: kubectl get nodes"

step "Done"
echo "AKS_ID=$AKS_ID"
echo "Next: Lab 8, Step 2"
