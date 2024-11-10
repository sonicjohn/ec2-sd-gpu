terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
    key    = "tfstate"
    region = var.AWS_DEFAULT_REGION
    dynamodb_table = "terraform_state_lock"
  }
}

# configure the aws provider
provider "aws" {
  region = var.AWS_DEFAULT_REGION
}

