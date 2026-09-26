terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "dtag-infra"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    #profile      = "dtag-s3-bucket"
    use_lockfile = true
  }
}
