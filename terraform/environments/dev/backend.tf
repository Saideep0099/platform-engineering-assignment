# Remote state in S3 with DynamoDB locking:
# - S3 gives durable, versioned, shared state
# - DynamoDB lock prevents two engineers/pipelines applying concurrently
terraform {
  backend "s3" {
    bucket         = "acme-terraform-state"
    key            = "platform/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
  required_version = ">= 1.7"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}
provider "aws" { region = "us-east-1" }
