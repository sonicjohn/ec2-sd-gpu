terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  backend "s3" {
    key    = "tfstate"
    region = "us-west-2"
    dynamodb_table = "terraform_state_lock"
  }
}

# configure the aws provider
provider "aws" {
  region = "us-west-2"
}

