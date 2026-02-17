locals {
  function_name = "${var.project}-${var.environment}-osm-beach-extractor"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/src/handler.py"
  output_path = "${path.module}/dist/handler.zip"
}

# --- IAM ---

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${local.function_name}-role"
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid       = "S3PutObject"
    actions   = ["s3:PutObject"]
    resources = ["${var.s3_bucket_arn}/${var.s3_prefix}/*"]
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  statement {
    sid = "XRayWrite"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

# --- CloudWatch ---

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "/aws/lambda/${local.function_name}"
  }
}

# --- Lambda ---

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_115:Reserved concurrency not needed for infrequent batch job
  #checkov:skip=CKV_AWS_117:VPC not needed — Lambda calls public Overpass API and S3
  #checkov:skip=CKV_AWS_173:No secrets in env vars — only bucket name and prefix
  #checkov:skip=CKV_AWS_272:Code signing not required for internal infra Lambda
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.14"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      S3_BUCKET = var.s3_bucket_name
      S3_PREFIX = var.s3_prefix
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy.lambda,
    aws_cloudwatch_log_group.lambda,
  ]

  tags = {
    Name = local.function_name
  }
}
