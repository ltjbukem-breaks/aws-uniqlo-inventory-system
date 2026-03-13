# This is where the Terraform variables used across various terraform scripts
# source the dynamic variables from

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "uniqlo-sales-etl"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16" # Gives us 65,536 IP addresses
}

variable "alert_email" {
  description = "Email address for DLQ alerts"
  type        = string
  default     = "" # Left blank - locally set in terraform.tfvars, added in .gitignore
}
