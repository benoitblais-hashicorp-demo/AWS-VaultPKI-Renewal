terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.36"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.8"
    }
  }
}
