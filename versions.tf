terraform {
  required_version = "~> 1.10.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws",
      version = ">= 5.84.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.26.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}
provider "aws" {
  region = "us-east-1"
  alias  = "useast1"
}
provider "awscc" {
  region = "us-east-2"
}