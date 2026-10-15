# Lab 3: Inspect the GitHub OIDC token

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

## Exercises

1. Compare the `sub` claim of the two jobs. This difference is why you need a separate federated credential for each environment.
2. Find `aud`, `iss`, `exp` and `iat`. How many minutes is the token valid for?
3. Create a branch, then run the workflow on it:
   ```bash
   git switch -c feature/test && git push -u origin feature/test
   gh workflow run 02-inspect-token.yml --ref feature/test
   ```
   What is `sub` now? Would Azure accept it? (Hint: try `01-login-oidc.yml` on this branch in Lab 4.)
4. Look at the other claims: `repository_owner_id`, `job_workflow_ref`, `actor`, `event_name`. These are useful
   for advanced trust rules (see Lab 7).

> If GitHub shows a different `sub` format than in the table (for example, because your org has customized the
> subject claim), **this lab is how you find the exact value** to put in the federated credential.

Next: [Lab 4: Break it on purpose](04-break-it.md)
