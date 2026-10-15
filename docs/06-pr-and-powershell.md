# Lab 6: Pull requests and Azure PowerShell

## Part A: Pull request subject

Workflow: [`.github/workflows/05-pull-request.yml`](../.github/workflows/05-pull-request.yml)

1. Create a branch, change any file under `docs/`, and open a PR:
   ```bash
   git switch -c pr-test
   echo "test" >> docs/notes.md
   git add . && git commit -m "PR test" && git push -u origin pr-test
   gh pr create --fill
   ```
2. The workflow runs on `pull_request`. Its subject is `repo:OWNER/REPO:pull_request`, which is the same for **every** PR,
   whatever the branch name.
3. It runs read-only checks (a "plan" or "what-if" style job).

> **Security note:** In this lab the PR credential uses the same app as `main`, so the PR job also has **Contributor**.
> Anyone who can open a PR in your repo could change the workflow and use that access. In real projects, use a
> **separate app registration with the Reader role** for PRs. That is Challenge 1 in Lab 7.

Close the PR when you are done: `gh pr close --delete-branch`.

## Part B: Azure PowerShell

Workflow: [`.github/workflows/06-azure-powershell.yml`](../.github/workflows/06-azure-powershell.yml)

Add `enable-AzPSSession: true` to `azure/login`. The same OIDC login then also signs in the Az PowerShell module:

```bash
gh workflow run 06-azure-powershell.yml --ref main
```

Look at the `Get-AzContext` output: the account is the app's client ID.

Next: [Lab 7: Challenges & cleanup](07-challenges-and-cleanup.md)
