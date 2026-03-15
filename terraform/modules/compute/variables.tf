variable "project_name" {}
variable "environment" {}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC config"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
}

variable "db_secret_arn" {
  description = "ARN of Secrets Manager secret for DB credentials"
}

variable "sales_data_bucket_name" {
  description = "Name of the sales data S3 bucket"
}

variable "product_updates_bucket_name" {
  description = "Name of the product updates S3 bucket"
}

variable "sales_data_bucket_arn" {
  description = "ARN of the sales data S3 bucket"
}

variable "product_updates_bucket_arn" {
  description = "ARN of the product updates S3 bucket"
}
