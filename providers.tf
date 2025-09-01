terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    tls = {
      source = "hashicorp/tls"
    }
    random = {
      source = "hashicorp/random"
    }
    archive = {
      source = "hashicorp/archive"
    }
    external = {
      source = "hashicorp/external"
    }
    local = {
      source = "hashicorp/local"
    }

  }

  backend "s3" {
    bucket = "001a2b3"
    key    = "terraform.tfstate"
    region = "eu-west-2"
  }
}

# Add explicit provider configuration
provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project     = "CSO HA Primary"
      Environment = terraform.workspace
      ManagedBy   = "terraform"
      Owner       = "CSO"
      CostCenter  = "IT-Infrastructure"
      Compliance  = "required"
    }
  }
}