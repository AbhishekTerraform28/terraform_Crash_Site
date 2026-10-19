terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "abhi-sre-lock-lab-v120261019175355256900000001"
    key            = "prod/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-north-1"
}

# 1. Real VPC (Will Succeed)
resource "aws_vpc" "crash_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "crash-lab-vpc"
  }
}

# 2. Real Subnet (Will Succeed)
resource "aws_subnet" "crash_subnet" {
  vpc_id                  = aws_vpc.crash_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "crash-lab-subnet"
  }
}

# 3. Fixed EC2 Instance
resource "aws_instance" "crash_ec2" {
  ami           = "ami-0a7acf71650e53201"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.crash_subnet.id

 tags = {
    Name        = "crash-lab-ec2"
    Environment = "Production-Manual"
  }
} 

# --- Backend Setup (S3 + DynamoDB) ---

# 1. Remote State Store karne ke liye S3 Bucket
resource "aws_s3_bucket" "tf_state_bucket" {
  bucket_prefix = "abhi-sre-lock-lab-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 2. State Lock manage karne ke liye DynamoDB Table
resource "aws_dynamodb_table" "tf_locks" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# --- Secrets Manager Integration ---

# 1. AWS Secrets Manager metadata
data "aws_secretsmanager_secret" "app_db_meta" {
  name = "prod/app/db_creds"
}

# 2. Secret payload
data "aws_secretsmanager_secret_version" "app_db_payload" {
  secret_id = data.aws_secretsmanager_secret.app_db_meta.id
}

# 3. Memory decode
locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.app_db_payload.secret_string)
}

# 4. Sensitive output
output "db_user" {
  value     = local.db_credentials.username
  sensitive = true
}

# Terminal me bucket name dekhne ke liye output
output "bucket_name" {
  value = aws_s3_bucket.tf_state_bucket.id
}

