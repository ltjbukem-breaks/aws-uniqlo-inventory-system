variable "project_name" {}
variable "environment" {}

variable "inventory_restock_lambda_arn" {
  description = "ARN of the inventory restock Lambda"
}

variable "inventory_restock_function_name" {
  description = "Name of the inventory restock Lambda"
}
