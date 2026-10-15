# Lab 6: Deploy through a protected GitHub environment

Workflow: [`.github/workflows/04-deploy-environment.yml`](../.github/workflows/04-deploy-environment.yml)

Environments let you add **approval gates** before a job can get an Azure token. Because the federated credential
trusts `environment:production`, only jobs that pass the environment's protection rules can log in.

## 1. Add a required reviewer

**Settings → Environments → production → Required reviewers →** add yourself → **Save protection rules**.

(Optional) Under **Deployment branches and tags**, choose **Selected branches** and add `main`.

## 2. Run the deploy

```bash
gh workflow run 04-deploy-environment.yml --ref main -f identity=app-registration
```

The run pauses at **Waiting for review**. Approve it in the Actions UI. The job then:

1. Logs in with OIDC (subject `<PREFIX>:environment:production`)
2. Creates a storage account in your lab resource group (the name comes from a hash of your repo name)
3. Prints its blob endpoint

Check it:
```bash
az storage account list -g rg-oidc-lab -o table
```

## 3. Prove the environment is the security boundary

1. Run the deploy again with `-f identity=managed-identity`. It works too: the managed identity also has a
   `gh-env-production` credential (Lab 2, Step 5), and the storage account already exists, so nothing changes.
2. Delete the managed identity's environment credential:
   ```bash
   az identity federated-credential delete -g rg-oidc-lab-identity --identity-name id-gh-oidc-lab -n gh-env-production --yes
   ```
3. Run the deploy with `managed-identity` again. It fails with `AADSTS700213`, even though the branch is `main`
   and the identity still has a `gh-branch-main` credential, because the job's subject is now the environment form.
4. Create the credential again yourself (Lab 2, Step 5) and check that the deploy works.

## Questions

1. Why is an environment-scoped credential safer than a branch-scoped one?
   (Hint: who can push to `main`, and who can approve the `production` environment?)
2. How would you set up `dev`, `test` and `prod` with a different Azure identity and scope for each?

Next: [Lab 7: Pull requests & PowerShell](07-pr-and-powershell.md)
