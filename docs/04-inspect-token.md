# Lab 4: Inspect the GitHub OIDC token

Workflow: [`.github/workflows/02-inspect-token.yml`](../.github/workflows/02-inspect-token.yml)

`azure/login` hides the token exchange. In this lab you request the same token yourself and decode its **claims**
(the JSON payload). The workflow prints only the claims, never the raw token.

## Run it

```bash
gh workflow run 02-inspect-token.yml --ref main
gh run watch
```

The workflow has **two jobs**:

| Job | Environment | Expected `sub` |
|-----|-------------|----------------|
| `claims-branch` | none | `repo:OWNER/REPO:ref:refs/heads/main` |
| `claims-environment` | `production` | `repo:OWNER/REPO:environment:production` |

Notice that this workflow never mentions an Azure identity. The token comes from **GitHub**, and it is the same whether
you then sign in with the app registration or the managed identity.

## Exercises

1. Compare the `sub` claim of the two jobs. This difference is why you need a separate federated credential for each environment.
2. Find `aud`, `iss`, `exp` and `iat`. How many minutes is the token valid for?
3. Create a branch, then run the workflow on it:
   ```bash
   git switch -c feature/test && git push -u origin feature/test
   gh workflow run 02-inspect-token.yml --ref feature/test
   ```
   What is `sub` now? Would Azure accept it? (Hint: try `01-login-oidc.yml` on this branch in Lab 5.)
4. Look at the other claims: `repository_owner_id`, `job_workflow_ref`, `actor`, `event_name`. These are useful
   for advanced trust rules (see Lab 9).

> If GitHub shows a different `sub` format than in the table (for example, because your org has customized the
> subject claim), **this lab is how you find the exact value** to put in the federated credential.

Next: [Lab 5: Break it on purpose](05-break-it.md)
