provider "aws" {
  region = var.aws_region

  # Apply default tags to most AWS resources created by this provider.
  default_tags {
    tags = {
      Project     = var.cluster_name
    }
  }
}

// Optionally enable a profile by setting AWS_PROFILE in your environment, or
// set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY before running Terraform.
