/*
# S3 Bucket
resource "aws_s3_bucket" "dtag_infra" {
  bucket = "dtag-infra"
  
  lifecycle {
    prevent_destroy = false
  }

  #acl    = "private" -->its deprecated.
  tags = {
    Name        = "dtag-infra"
    Environment = "Dev"
  }
}
*/