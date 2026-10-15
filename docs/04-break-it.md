# Lab 4: Break it on purpose (troubleshooting)

Workflow: [`.github/workflows/03-break-it.yml`](../.github/workflows/03-break-it.yml)

Real OIDC problems are almost always one of these three. Each scenario **fails on purpose**. Read the error and match it to its cause.

```bash
gh workflow run 03-break-it.yml -f scenario=missing-id-token-permission
gh workflow run 03-break-it.yml -f scenario=wrong-audience
gh workflow run 03-break-it.yml -f scenario=unknown-client-id
```

## Scenario 1: Missing `id-token: write`

The job has `permissions: contents: read` only.

Typical error:
```
Error: Unable to get ACTIONS_ID_TOKEN_REQUEST_URL env variable
```
**Fix:** Add `id-token: write` at the workflow or job level.
**Also note:** For pull requests from **forks**, GitHub never grants `id-token: write`, so OIDC cannot work there.

## Scenario 2: Wrong audience

The job sets `audience: api://SomethingElse`, so the token's `aud` does not match the federated credential.

Typical error:
```
AADSTS700212 / AADSTS70021: No matching federated identity record found for presented assertion audience ...
```
**Fix:** Leave `audience` at its default (`api://AzureADTokenExchange`), or make it match the credential.

## Scenario 3: Wrong client ID

The job uses a random GUID as the client ID.

Typical error:
```
AADSTS700016: Application with identifier '...' was not found in the directory ...
```
**Fix:** Check that `AZURE_CLIENT_ID` is the **Application (client) ID**, not the Object ID, and that `AZURE_TENANT_ID` is correct.

## Scenario 4: Subject mismatch (the most common one)

You do not need the break-it workflow for this one. Run the normal login workflow on a branch that has no credential:

```bash
gh workflow run 01-login-oidc.yml --ref feature/test
```

Typical error:
```
AADSTS700213: No matching federated identity record found for presented assertion subject
'repo:OWNER/REPO:ref:refs/heads/feature/test'
```
**Fix:** The error tells you the exact subject. Either add a federated credential for it, or (better) deploy only from
`main` or an environment. Subjects must match exactly: wildcards are **not** supported in standard federated credentials.

## Troubleshooting checklist

1. Is `id-token: write` set on the job?
2. Does the `sub` from the error, or from Lab 3, match a credential **exactly**, including case?
3. Does the job use an `environment`? If so, the subject is `environment:NAME`, not `ref:...`.
4. Is the client ID the *application* ID, and is the tenant ID correct?
5. Login works but commands fail with `AuthorizationFailed`? Then OIDC is fine. Check the **RBAC** role and scope.

Next: [Lab 5: Environments](05-environments.md)
