#AWS Region
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}
#AWS Profile
variable "aws_profile" {
  description = "AWS Profile"
  type        = string
  default     = "dtag-dev"
}
#S3 Bucket Configuration

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "dtag-s3-bucket"
}