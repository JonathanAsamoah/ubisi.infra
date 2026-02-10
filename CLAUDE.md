# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS infrastructure managed with OpenTofu (Terraform-compatible) and Terragrunt for DRY configuration and multi-environment orchestration. Primary region: `eu-west-1`.

## Tech Stack

- **OpenTofu** — Infrastructure as Code (Terraform fork)
- **Terragrunt** — Wrapper for OpenTofu providing DRY configurations, remote state management, and dependency orchestration
- **AWS** — Cloud provider (eu-west-1)

## Bootstrap (First-Time Setup)

Before any other module can be applied, create the remote state backend:

```bash
cd bootstrap/
terragrunt init
terragrunt apply
```

This creates the S3 bucket (`ubisi-tfstate-dev`) and DynamoDB table (`ubisi-tflock-dev`) using a local backend. Run once per environment. After this, all other modules use the remote S3 backend automatically.

## Common Commands

```bash
# Initialize a module (run from a leaf terragrunt.hcl directory)
terragrunt init

# Plan/apply a single module
terragrunt plan
terragrunt apply

# Plan/apply all modules in a directory tree
terragrunt run-all plan
terragrunt run-all apply

# Format all .tf files
tofu fmt -recursive

# Validate configuration
terragrunt validate

# Show current state
terragrunt state list
```

All `terragrunt` commands must be run from within a leaf directory containing a `terragrunt.hcl` file (e.g. `environments/dev/eu-west-1/vpc/`).

## Architecture

```
├── terragrunt.hcl                          # Root config: remote state (S3 + DynamoDB), provider generation, common inputs
├── bootstrap/
│   └── terragrunt.hcl                      # Standalone: creates state bucket + lock table (local backend)
├── modules/                                # Reusable OpenTofu modules (source of truth for resources)
│   └── <module>/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    └── <env>/
        ├── env.hcl                         # Environment name
        └── <region>/
            ├── region.hcl                  # AWS region
            └── <module>/
                └── terragrunt.hcl          # Wires module source + env-specific inputs
```

- **Root `terragrunt.hcl`** — reads `env.hcl` and `region.hcl` from parent folders via `find_in_parent_folders()`. Generates `backend.tf` (S3 state) and `provider.tf` (AWS provider with default tags). Passes `environment`, `aws_region`, and `project` as common inputs to all modules.
- **`modules/`** — generic, reusable OpenTofu modules with no environment-specific logic. Each module declares `variables.tf` inputs and `outputs.tf` for cross-module references.
- **Leaf `terragrunt.hcl`** — sets `terraform.source` to a local module path and provides environment-specific `inputs`. Uses `include "root"` to inherit the root config. Cross-module references use Terragrunt `dependency` blocks.

## Conventions

- State bucket: `ubisi-tfstate-<env>`, lock table: `ubisi-tflock-<env>`
- Default tags (`Environment`, `Project`, `ManagedBy=opentofu`) are applied via the provider block — add resource-specific tags (like `Name`) in modules
- Use Terragrunt `dependency` blocks (not hardcoded values) to reference outputs across modules
- Sensitive values go in AWS Secrets Manager or SSM Parameter Store, never in `.tf` or `.hcl` files

## CI/CD

GitHub Actions pipelines in `.github/workflows/`:

- **`plan.yml`** — runs `terragrunt run-all plan` on PRs targeting `main`, posts the plan output as a PR comment. Triggered by changes to `modules/`, `environments/`, or root `terragrunt.hcl`.
- **`apply.yml`** — runs `terragrunt run-all apply` on merge to `main` (same path filters). Uses a `concurrency` group to prevent parallel applies. Requires the `dev` GitHub environment.

Both authenticate via **OIDC** — the repo assumes an IAM role specified by the `AWS_ROLE_ARN` repository variable (no long-lived credentials). The OIDC provider and IAM role must be set up in AWS before the pipeline can run.

## Security Scanning (Checkov)

[Checkov](https://www.checkov.io/) runs static security analysis on the OpenTofu modules. Configuration lives in `.checkov.yml` at the repo root.

```bash
# Install (one-time)
pip install checkov

# Run from repo root — picks up .checkov.yml automatically
checkov
```

- **Scope:** scans `modules/` only (framework: `terraform`)
- **Soft-fail:** enabled — findings are informational and don't block CI
- **Skip list:** documented in `.checkov.yml` with reasons for each suppressed check
- **CI:** runs as a separate `security` job in `plan.yml`, posts results as a PR comment

## Adding a New Module

1. Create `modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`
2. Create `environments/<env>/<region>/<name>/terragrunt.hcl` pointing to the module with env-specific inputs
3. If the module depends on another (e.g. needs VPC ID), add a `dependency` block and reference its outputs
