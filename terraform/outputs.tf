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