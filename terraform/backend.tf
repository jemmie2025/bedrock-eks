# Terraform Backend Configuration
# This file configures remote state storage in S3 with DynamoDB locking

terraform {
  backend "s3" {
    bucket         = "bedrock-terraform-state-alt-soe-025-1483"
    key            = "bedrock/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bedrock-terraform-locks"
    encrypt        = true
  }
}