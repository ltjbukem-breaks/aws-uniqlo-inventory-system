# TODO: Define outputs that will be displayed after terraform apply
# We'll add outputs as we build each module

# Example outputs we'll add later:
# - VPC ID
# - RDS endpoint
# - S3 bucket names
# - Lambda function ARNs

# Networking outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = module.networking.lambda_security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = module.networking.rds_security_group_id
}

# Storage outputs
output "sales_data_bucket_name" {
  description = "Name of S3 bucket for sales data"
  value       = module.storage.sales_data_bucket_name
}

output "product_updates_bucket_name" {
  description = "Name of S3 bucket for product updates"
  value       = module.storage.product_updates_bucket_name
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.storage.rds_endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.storage.rds_database_name
}

output "db_secret_arn" {
  description = "ARN of Secrets Manager secret containing DB credentials"
  value       = module.storage.db_secret_arn
}

# Compute outputs
output "sales_processor_arn" {
  description = "ARN of sales processor Lambda"
  value       = module.compute.sales_processor_arn
}

output "product_updater_arn" {
  description = "ARN of product updater Lambda"
  value       = module.compute.product_updater_arn
}

output "inventory_restock_arn" {
  description = "ARN of inventory restock Lambda"
  value       = module.compute.inventory_restock_arn
}
