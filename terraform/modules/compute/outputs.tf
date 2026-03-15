output "sales_processor_arn" {
  description = "ARN of sales processor Lambda"
  value       = aws_lambda_function.sales_processor.arn
}

output "product_updater_arn" {
  description = "ARN of product updater Lambda"
  value       = aws_lambda_function.product_updater.arn
}

output "inventory_restock_arn" {
  description = "ARN of inventory restock Lambda"
  value       = aws_lambda_function.inventory_restock.arn
}

output "sales_processor_function_name" {
  description = "Name of sales processor Lambda"
  value       = aws_lambda_function.sales_processor.function_name
}

output "product_updater_function_name" {
  description = "Name of product updater Lambda"
  value       = aws_lambda_function.product_updater.function_name
}

output "inventory_restock_function_name" {
  description = "Name of inventory restock Lambda"
  value       = aws_lambda_function.inventory_restock.function_name
}
