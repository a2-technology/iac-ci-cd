locals {
  identifier = "${var.workload_name}-tf-state"
  developers = "${var.workload_name}-tf-developers"
  tags = {
    name        = "${local.identifier}"
    workload    = "${var.workload_name}"
    environment = "all"
    cost-center = "DevOps"
  }
}

resource "aws_s3_bucket" "tf_state_bucket" {
  bucket = local.identifier
  tags   = local.tags
}

# Ignore other ACLs to ensure bucket stays private
resource "aws_s3_bucket_public_access_block" "tf_state_bucket" {
  bucket                  = aws_s3_bucket.tf_state_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Set ownership controls to bucket to prevent access from other AWS accounts
resource "aws_s3_bucket_ownership_controls" "tf_state_bucket" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Set bucket ACL to private
resource "aws_s3_bucket_acl" "tf_state_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.tf_state_bucket,
    aws_s3_bucket_public_access_block.tf_state_bucket,
  ]
  bucket = aws_s3_bucket.tf_state_bucket.id
  acl    = "private"
}

# Enable bucket versioning
resource "aws_s3_bucket_versioning" "tf_state_bucket" {
  bucket = aws_s3_bucket.tf_state_bucket.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

# Encryption key for state files
resource "aws_kms_key" "tf_state_encryption" {
  description             = "Key to encrypt state for ${var.workload_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = local.tags
}
resource "aws_kms_alias" "tf_state_s3" {
  name          = "alias/${local.identifier}-s3"
  target_key_id = aws_kms_key.tf_state_encryption.key_id
}

# Bucket encryption settings
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_bucket_sse" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_alias.tf_state_s3.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_dynamodb_table" "tf_state_lock" {
  name         = "${local.identifier}-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  # This attribute is mandatory
  # https://developer.hashicorp.com/terraform/language/settings/backends/s3#configuration
  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = local.tags
}

# IAM Policy document to access the S3 bucket and DynamoDB table used by
# the state file.
data "aws_iam_policy_document" "tf_state_access_permissions_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      "${aws_dynamodb_table.tf_state_lock.arn}",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.tf_state_bucket.arn}",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.tf_state_bucket.arn}/*/terraform.tfstate",
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:ReEncrypt*",       # needed for bucket keys
      "kms:GenerateDataKey*", # needed for bucket keys
    ]
    resources = [
      "${aws_kms_alias.tf_state_s3.target_key_arn}/",
    ]
  }
}

resource "aws_iam_policy" "tf_state_access_iam_policy" {
  name   = "${local.developers}-policy"
  policy = data.aws_iam_policy_document.tf_state_access_permissions_policy.json
  tags   = local.tags
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "tf_developers_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    # This has to be created outside of terraform
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/${var.region}/${var.sso_role_name}"]
    }
  }
}

resource "aws_iam_role" "tf_developers" {
  name               = local.developers
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.tf_developers_assume_role_policy.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "tf_developers_permissions_policy" {
  role       = aws_iam_role.tf_developers.name
  policy_arn = aws_iam_policy.tf_state_access_iam_policy.arn
}

resource "aws_ssm_parameter" "developer_role_arn" {
  name  = local.developers
  type  = "String"
  value = aws_iam_role.tf_developers.arn
}

resource "aws_ssm_parameter" "tf_state_bucket" {
  name  = local.identifier
  type  = "String"
  value = aws_s3_bucket.tf_state_bucket.arn
}