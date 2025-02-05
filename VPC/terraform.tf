terraform {
  backend "s3" {
    bucket         = "taron-aca-tformstate"
    key            = "project1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
  required_providers {
    aws = {
      version = ">=5.82.2"
    }
  }
}

