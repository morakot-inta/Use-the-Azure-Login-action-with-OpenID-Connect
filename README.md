# Lab: Azure Login action with OpenID Connect (OIDC)

Learn how GitHub Actions signs in to Azure **without storing any secret or password**.
GitHub issues a short-lived OIDC token, and Microsoft Entra ID swaps it for an Azure access token
because you set up a *federated identity credential* that trusts it.

## What you will learn

| # | Lab | Workflow | You will... |
|---|-----|----------|-------------|
| 0 | [Concepts](docs/00-concepts.md) | – | Understand the token exchange end to end |
| 1 | [Set up the trust](docs/01-setup-trust.md) | – | Create the app registration, service principal, federated credentials and RBAC |
| 2 | [First login](docs/02-first-login.md) | `01-login-oidc.yml` | Log in with `azure/login` and run Azure CLI |
| 3 | [Inspect the token](docs/03-inspect-token.md) | `02-inspect-token.yml` | Decode the GitHub OIDC token and read its `sub`, `aud`, `iss` claims |
| 4 | [Break it on purpose](docs/04-break-it.md) | `03-break-it.yml` | Cause and fix the 3 most common OIDC errors |
| 5 | [Environments](docs/05-environments.md) | `04-deploy-environment.yml` | Deploy through a protected GitHub environment |
| 6 | [Pull requests & PowerShell](docs/06-pr-and-powershell.md) | `05-pull-request.yml`, `06-azure-powershell.yml` | Use other subject types and Azure PowerShell |
| 7 | [Challenges & cleanup](docs/07-challenges-and-cleanup.md) | – | Least privilege, managed identity, delete everything |

## Prerequisites

- An Azure subscription where you can **create app registrations** and **assign roles**
  (Owner or User Access Administrator + Application Developer)
- A GitHub repository you own. Push this folder to it.
- Locally: [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`), [GitHub CLI](https://cli.github.com/) (`gh`), `bash`, `jq`

## Quick start

```bash
# 1. Push this lab to your own GitHub repo
git init && git add . && git commit -m "OIDC lab"
gh repo create oidc-lab --private --source . --push

# 2. Configure and create the Azure trust
cp scripts/config.env.example scripts/config.env   # edit GITHUB_REPO etc.
az login
./scripts/setup-oidc.sh

# 3. Run your first workflow
gh workflow run 01-login-oidc.yml && gh run watch
```

When you are done, run `./scripts/cleanup.sh` (see [Lab 7](docs/07-challenges-and-cleanup.md)).

## Repo layout

```
.github/workflows/   Lab workflows (01–06)
docs/                Step-by-step lab guides
scripts/             setup-oidc.sh, cleanup.sh, config.env.example
```

> **Cost:** The only billable resource is one Standard_LRS storage account (Lab 5), which costs a few cents.
> The cleanup script deletes it.
