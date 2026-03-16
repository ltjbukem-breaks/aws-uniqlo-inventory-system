# SQS DLQs - one per Lambda
resource "aws_sqs_queue" "sales_processor_dlq" {
  name                      = "${var.project_name}-${var.environment}-sales-processor-dlq"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "product_updater_dlq" {
  name                      = "${var.project_name}-${var.environment}-product-updater-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "inventory_restock_dlq" {
  name                      = "${var.project_name}-${var.environment}-inventory-restock-dlq"
  message_retention_seconds = 1209600
}

# SNS topic for alerts
resource "aws_sns_topic" "dlq_alerts" {
  name = "${var.project_name}-${var.environment}-dlq-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.dlq_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch alarms - one per DLQ, triggers SNS when messages appear
resource "aws_cloudwatch_metric_alarm" "sales_processor_dlq" {
  alarm_name          = "${var.project_name}-${var.environment}-sales-processor-dlq-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "sales-processor Lambda is sending failures to DLQ"
  alarm_actions       = [aws_sns_topic.dlq_alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.sales_processor_dlq.name
  }
}

resource "aws_cloudwatch_metric_alarm" "product_updater_dlq" {
  alarm_name          = "${var.project_name}-${var.environment}-product-updater-dlq-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "product-updater Lambda is sending failures to DLQ"
  alarm_actions       = [aws_sns_topic.dlq_alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.product_updater_dlq.name
  }
}

resource "aws_cloudwatch_metric_alarm" "inventory_restock_dlq" {
  alarm_name          = "${var.project_name}-${var.environment}-inventory-restock-dlq-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "inventory-restock Lambda is sending failures to DLQ"
  alarm_actions       = [aws_sns_topic.dlq_alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.inventory_restock_dlq.name
  }
}
