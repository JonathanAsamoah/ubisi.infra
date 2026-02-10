# Setting Up AWS OIDC for GitHub Actions

This guide walks through configuring GitHub Actions to authenticate with AWS using OpenID Connect (OIDC), so the CI/CD pipelines can deploy infrastructure without long-lived access keys.

## Overview

The setup has three parts:

1. Create an OIDC identity provider in AWS that trusts GitHub
2. Create an IAM role that the GitHub Actions workflows can assume
3. Configure the GitHub repository with the role ARN

## Step 1: Create the GitHub OIDC Provider in AWS

In the AWS Console (IAM > Identity providers > Add provider):

- **Provider type:** OpenID Connect
- **Provider URL:** `https://token.actions.githubusercontent.com`
- **Audience:** `sts.amazonaws.com`

Or via AWS CLI:

```bash
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
```

> The thumbprint may change over time. AWS now automatically verifies GitHub's certificate chain, so the thumbprint value is not strictly validated, but the parameter is still required by the API.

Note the ARN of the provider — it will look like:
```
arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
```

## Step 2: Create the IAM Role

### Trust Policy

Create a file `trust-policy.json`. Replace `<ACCOUNT_ID>` with your AWS account ID and `<GITHUB_ORG>/<GITHUB_REPO>` with your repository (e.g. `ubisi/ubisi-infra`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::303289350912:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:JonathanAsamoah/ubisi.infra:*"
        }
      }
    }
  ]
}
```

To restrict which branches can assume the role, replace the `StringLike` sub condition:

```json
"token.actions.githubusercontent.com:sub": "repo:<GITHUB_ORG>/<GITHUB_REPO>:ref:refs/heads/main"
```

### Create the Role

```bash
aws iam create-role \
  --role-name ubisi-infra-github-actions \
  --assume-role-policy-document file://trust-policy.json
```

### Attach Permissions

Attach the permissions the role needs. For full infrastructure management, `AdministratorAccess` works but is broad. A more scoped approach:

```bash
# Option A: Full admin (simple, less secure)
aws iam attach-role-policy \
  --role-name ubisi-infra-github-actions \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Option B: Scoped to specific services (recommended for production)
# Create a custom policy with only the permissions your modules need,
# plus s3/dynamodb access for the state backend:
#   - s3:GetObject, s3:PutObject, s3:ListBucket on the state bucket
#   - dynamodb:GetItem, dynamodb:PutItem, dynamodb:DeleteItem on the lock table
#   - ec2:* (or scoped VPC permissions) for infrastructure modules
```

Note the role ARN:
```
arn:aws:iam::<ACCOUNT_ID>:role/ubisi-infra-github-actions
```

## Step 3: Configure GitHub Repository

1. Go to your repository on GitHub
2. Navigate to **Settings > Secrets and variables > Actions > Variables**
3. Add a new **repository variable**:
   - **Name:** `AWS_ROLE_ARN`
   - **Value:** `arn:aws:iam::<ACCOUNT_ID>:role/ubisi-infra-github-actions`

### Optional: Create GitHub Environment

For an approval gate before applies:

1. Go to **Settings > Environments**
2. Create an environment named `dev`
3. Optionally add **required reviewers** so applies need manual approval
4. Optionally restrict deployment to the `main` branch

## Verifying the Setup

Push a branch with a small change to any file under `environments/` or `modules/` and open a PR. The `Terragrunt Plan` workflow should:

1. Successfully authenticate with AWS (no credential errors)
2. Run `terragrunt run-all plan`
3. Post the plan output as a PR comment

If authentication fails, check:

- The OIDC provider exists in IAM and the URL is exactly `https://token.actions.githubusercontent.com`
- The trust policy `sub` condition matches your repository name (case-sensitive)
- The role ARN in the `AWS_ROLE_ARN` GitHub variable is correct
- The workflow has `permissions: id-token: write`

## Security Considerations

- **Scope the trust policy** to specific branches or environments when possible, rather than using `repo:org/repo:*`
- **Use least-privilege IAM permissions** — start broad for initial setup, then tighten based on what your modules actually need
- **Rotate nothing** — OIDC tokens are short-lived and issued per workflow run, so there are no credentials to rotate
