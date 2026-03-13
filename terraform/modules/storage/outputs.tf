# Outputs from storage module

# TODO: Output S3 bucket names
output "sales_data_bucket_name" {
  description = "Name of S3 bucket for sales data"
  value       = aws_s3_bucket.sales_data.id
}

output "product_updates_bucket_name" {
  description = "Name of S3 bucket for product updates"
  value       = aws_s3_bucket.product_updates.id
}

# TODO: Output RDS endpoint
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

# TODO: Output Secrets Manager ARN
output "db_secret_arn" {
  description = "ARN of Secrets Manager secret containing DB credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}
