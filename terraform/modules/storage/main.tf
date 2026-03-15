# ============================================
# S3 Buckets
# ============================================

# Create S3 bucket for sales data
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
resource "aws_s3_bucket" "sales_data" {
  bucket = "${var.project_name}-sales-data-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-sales-data"
  }
}

# Enable versioning for sales data bucket
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
resource "aws_s3_bucket_versioning" "sales_data" {
  bucket = aws_s3_bucket.sales_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to sales data bucket
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
resource "aws_s3_bucket_public_access_block" "sales_data" {
  bucket = aws_s3_bucket.sales_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create S3 bucket for product updates
resource "aws_s3_bucket" "product_updates" {
  bucket = "${var.project_name}-product-updates-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.project_name}-product-updates"
  }
}

# Enable versioning for product updates bucket
resource "aws_s3_bucket_versioning" "product_updates" {
  bucket = aws_s3_bucket.product_updates.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to product updates bucket
resource "aws_s3_bucket_public_access_block" "product_updates" {
  bucket = aws_s3_bucket.product_updates.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================
# RDS PostgreSQL
# ============================================

# Generate random password for RDS
# Docs: https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Create DB subnet group (tells RDS which subnets to use)
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids # Uses both private subnets from networking module

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Create RDS PostgreSQL instance
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance
resource "aws_db_instance" "postgres" {
  identifier = "${var.project_name}-db"

  # Engine configuration
  engine         = "postgres"
  engine_version = "17.6"

  # Instance configuration
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3" # General Purpose SSD (gp3 is newer, same price as gp2)

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_password.result

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  publicly_accessible    = false # Keep in private subnet

  # Backup configuration
  backup_retention_period = 1                     # Keep backups for 7 days
  backup_window           = "03:00-04:00"         # UTC time
  maintenance_window      = "mon:04:00-mon:05:00" # UTC time

  # Set skip_final_snapshot for dev environment
  skip_final_snapshot = true

  # Enable deletion protection for production
  deletion_protection = false # Set to true for production

  # Performance Insights (optional, free for 7 days retention)
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${var.project_name}-postgres-db"
  }
}

# ============================================
# Secrets Manager
# ============================================

# Create Secrets Manager secret for DB credentials
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.project_name}-db-credentials"
  description = "RDS PostgreSQL credentials for ${var.project_name}"

  # Add recovery window (days to recover if accidentally deleted)
  recovery_window_in_days = 7 # 0 for immediate deletion (dev), 7-30 for production

  tags = {
    Name = "${var.project_name}-db-credentials"
  }
}

# Store DB credentials in Secrets Manager
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version
resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  # Store credentials as JSON
  secret_string = jsonencode({
    username = aws_db_instance.postgres.username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = aws_db_instance.postgres.db_name
  })
}

# ============================================
# Data Sources
# ============================================

# Get current AWS account ID (for unique S3 bucket names)
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}
