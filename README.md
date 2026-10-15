# Lab: Azure Login action with OpenID Connect (OIDC)

Learn how GitHub Actions signs in to Azure **without storing any secret or password**.
GitHub issues a short-lived OIDC token, and Microsoft Entra ID swaps it for an Azure access token
because you set up a *federated identity credential* that trusts it.

You build every piece **by hand**, one command (or one portal click) at a time, and check the result after each step.
There are no setup scripts, so you see and understand everything you create.

You will set up the trust with **two kinds of Azure identity** and compare them:

- **App registration + service principal**: the classic way
- **User-assigned managed identity**: no Entra app at all, and it can never have a secret

## Labs

| # | Lab | Workflow | You will... |
|---|-----|----------|-------------|
| 0 | [Concepts](docs/00-concepts.md) | – | Understand the token exchange and the two identity types |
| 1 | [Trust with an app registration](docs/01-setup-app-registration.md) | – | Create the app, service principal, RBAC and federated credentials by hand |
| 2 | [Trust with a managed identity](docs/02-setup-managed-identity.md) | – | Do the same with a user-assigned managed identity |
| 3 | [First login](docs/03-first-login.md) | `01-login-oidc.yml` | Log in with each identity and compare the results |
| 4 | [Inspect the token](docs/04-inspect-token.md) | `02-inspect-token.yml` | Decode the GitHub OIDC token and read its `sub`, `aud`, `iss` claims |
| 5 | [Break it on purpose](docs/05-break-it.md) | `03-break-it.yml` | Cause and fix the most common OIDC errors |
| 6 | [Environments](docs/06-environments.md) | `04-deploy-environment.yml` | Deploy through a protected GitHub environment |
| 7 | [Pull requests & PowerShell](docs/07-pr-and-powershell.md) | `05-pull-request.yml`, `06-azure-powershell.yml` | Use other subject types and Azure PowerShell |
| 8 | [Deploy to AKS](docs/08-aks.md) | `07-deploy-aks.yml` | Carry the OIDC login into Kubernetes with kubelogin and namespace-scoped RBAC |
| 9 | [Challenges & cleanup](docs/09-challenges-and-cleanup.md) | – | Least privilege, a self-escalation risk, and deleting everything |

## Prerequisites

- An Azure subscription where you have **Owner** (or Contributor + User Access Administrator) on a resource group
- For Lab 1 only: permission to **create app registrations** in Entra ID. If you don't have it, do Lab 2 and use the managed identity for every lab.
- A **fork or copy of this repo** in your own GitHub account. The federated credentials must name *your* repo.
- Lab 8 only: `kubectl` and `kubelogin` (`az aks install-cli`)
- Locally: [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`), [GitHub CLI](https://cli.github.com/) (`gh`), `bash`
  (or use [Azure Cloud Shell](https://shell.azure.com), which already has `az`)

## Repo layout

```
.github/workflows/   Lab workflows (01–07)
docs/                Step-by-step lab guides (00–09)
k8s/                 Sample app deployed to AKS in Lab 8
```

> **Cost:** Labs 1–7 create only one Standard_LRS storage account (a few cents).
> Lab 8 adds an AKS cluster with one `Standard_B2s` node (about USD 1 per day; stop it with `az aks stop` when you are not using it).
> Lab 9 shows how to delete everything.

Start here: [Lab 0: Concepts](docs/00-concepts.md)
