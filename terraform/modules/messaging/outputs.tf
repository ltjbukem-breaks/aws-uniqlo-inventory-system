output "sales_processor_dlq_arn" {
  value = aws_sqs_queue.sales_processor_dlq.arn
}

output "product_updater_dlq_arn" {
  value = aws_sqs_queue.product_updater_dlq.arn
}

output "inventory_restock_dlq_arn" {
  value = aws_sqs_queue.inventory_restock_dlq.arn
}