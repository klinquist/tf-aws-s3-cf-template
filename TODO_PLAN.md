# TODO Plan

This document outlines the work required to complete the TODOs listed in `README.md`.

## 1) Use the GitHub Terraform provider instead of `gh` CLI

### Goal
Provision the GitHub repository, secrets, and workflow setup via Terraform rather than `gh` CLI commands in `set-up-repo.sh`.

### Required decisions
- Authentication method for the GitHub provider: personal access token (PAT) vs. GitHub App.
- Whether repo creation is always desired or optional (flagged by a variable).

### Implementation tasks
- Add the GitHub provider and configuration.
  - New variables for `github_token`, `github_owner`, and `github_repo_name` (or a single `repo_name`).
  - Optional: allow a GitHub App configuration if you want to avoid PATs.
- Create the repository via `github_repository`.
  - Mirror current behavior (private repo, named after the domain by default).
- Configure GitHub Actions secrets via `github_actions_secret`.
  - Replace the `gh secret set` calls in `set-up-repo.sh`.
  - Wire in values from Terraform outputs or state (bucket name, CloudFront distribution ID, IAM keys).
- Set up the workflow file.
  - Choose between committing the file via Terraform (`github_repository_file`) or keeping a local file and letting the user commit manually.
- Update `set-up-repo.sh` to remove GitHub API responsibilities.
  - Keep only local tasks: git init, optional first commit, and guidance for the user.

### Files likely touched
- `main.tf` (GitHub provider, resources)
- `vars.tf` (new GitHub variables)
- `outputs.tf` (expose values for secrets)
- `set-up-repo.sh` (remove GitHub API steps)
- `README.md` (new prerequisites and usage)

### Acceptance checks
- `terraform apply` creates the GitHub repo and action secrets.
- Workflow file exists in the repository (or is clearly documented for manual commit).
- `set-up-repo.sh` no longer requires `gh`.

## 2) Set up GitHub-AWS OIDC instead of access keys

### Goal
Replace static IAM access keys with GitHub Actions OIDC federation to assume a role at deploy time.

### Required decisions
- Whether to keep IAM user/key support as an opt-in fallback.
- Scope of permissions (least privilege) for S3 and CloudFront invalidation.
- Repository/environment(s) allowed to assume the role.

### Implementation tasks
- Create an IAM OIDC identity provider for `token.actions.githubusercontent.com`.
- Create an IAM role with a trust policy allowing GitHub Actions to assume it.
  - Restrict by repository and workflow/ref claims.
- Attach least-privilege IAM policies to the role.
  - S3 sync (bucket and objects).
  - CloudFront invalidation for the distribution.
- Update GitHub Actions workflow.
  - Use `aws-actions/configure-aws-credentials` with role-to-assume.
  - Remove reliance on `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets.
- Update `set-up-repo.sh` and `README.md`.
  - Remove access key creation instructions.
  - Document required secrets (if any) and AWS role ARN usage.

### Files likely touched
- New IAM module files (or existing IAM module): `modules/iam-github/...`
- `main.tf` wiring for role outputs
- GitHub Actions workflow in `.github/workflows/deploy.yml`
- `README.md` (new security model, setup steps)
- `set-up-repo.sh` (remove access key handling)

### Acceptance checks
- GitHub Actions deploy succeeds without static AWS keys.
- IAM trust policy limits access to the intended repo/workflow.
- No AWS access keys are created or stored in GitHub secrets.
