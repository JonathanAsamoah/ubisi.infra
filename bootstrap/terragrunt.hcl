# Bootstrap — creates the S3 bucket and DynamoDB table for remote state.
# Uses local backend since the remote state infrastructure doesn't exist yet.
#
# Usage:
#   cd bootstrap/
#   terragrunt init
#   terragrunt apply
#
# This is a one-time operation per environment. After running, all other
# modules can use the remote S3 backend configured in the root terragrunt.hcl.

locals {
  project     = "ubisi"
  environment = "dev"
  aws_region  = "eu-west-1"
}

terraform {
  source = "../modules/state-backend"
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {}
}
EOF
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Environment = "${local.environment}"
      Project     = "${local.project}"
      ManagedBy   = "opentofu"
    }
  }
}
EOF
}

inputs = {
  project     = local.project
  environment = local.environment
}
