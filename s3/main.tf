# KMS Key for s3 bucket store data
resource "aws_kms_key" "dtag_s3_kms_key" {
  description             = "KMS key for S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags = {
    Name      = "dtag-s3-kms-key"
    Purpose   = "S3 bucket encryption"
    ManagedBy = "dtag-infra"
  }
}

#KMS Alias for s3 bucket store data

resource "aws_kms_alias" "dtag_s3_kms_alias" {
  name          = "alias/dtag-s3-kms-key"
  target_key_id = aws_kms_key.dtag_s3_kms_key.key_id
}

# AWS S3 Bucket Configuration
resource "aws_s3_bucket" "dtag_s3_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "dtag-s3-bucket"
    Environment = "Dev"
  }
}

#Bucket Access Control List (ACL)

resource "aws_s3_bucket_acl" "dtag_s3_bucket_acl" {
  bucket = aws_s3_bucket.dtag_s3_bucket.id
  acl    = "private"
}

# S3 Buket Ownership controls
resource "aws_s3_bucket_ownership_controls" "dtag_s3_bucket_ownership_controls" {
  bucket = aws_s3_bucket.dtag_s3_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "dtag_s3_bucket_versioning" {
  bucket = aws_s3_bucket.dtag_s3_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

#S3 Bucket server side encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "dtag_s3_bucket_encryption" {
  bucket = aws_s3_bucket.dtag_s3_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.dtag_s3_kms_key.arn
    }
    bucket_key_enabled = true
  }

}

#S3 Block Public Access Configuration

# ---------------------------------------------------------
# Block Public Access
# ---------------------------------------------------------
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.dtag_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}