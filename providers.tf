terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.99"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.7.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.4"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.3"
    }
  }
}
