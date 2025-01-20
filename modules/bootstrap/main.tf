locals {
    identifier = "${var.workload_name}-tf-state"
    developers = "${var.workload_name}-tf-developers"
    tags = {
        name = "${local.identifier}"
        workload = "${var.workload_name}"
        environment = "all"
        cost-center = "DevOps"
    }
}

resource "aws_s3_bucket" "tf_state_bucket" {
    bucket = local.identifier
    tags = local.tags
}

# Ignore other ACLs to ensure bucket stays private
resource "aws_s3_bucket_public_access_block" "tf_state_bucket" {
  bucket                  = aws_s3_bucket.tf_state_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
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
    status = "Enabled"
    mfa_delete = "Disabled"
  }
}

data "aws_kms_alias" "s3" {
    name = "${local.identifier}-s3"
}

# Bucket encryption settings
resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = data.aws_kms_alias.s3.target_key_arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_dynamodb_table" "tf_state_lock" {
  name           = "${local.identifier}-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

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
data "aws_iam_policy_document" "state_file_access_permissions" {
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
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
    ]
    resources = [
      "${data.aws_kms_alias.s3.target_key_arn}/",
    ]
  }

}
