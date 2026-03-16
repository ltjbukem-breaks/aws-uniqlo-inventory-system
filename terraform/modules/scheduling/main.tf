# EventBridge rule - fires daily at 2AM UTC
resource "aws_cloudwatch_event_rule" "inventory_restock" {
  name                = "${var.project_name}-${var.environment}-inventory-restock"
  schedule_expression = "cron(0 2 * * ? *)"
}

# Point the rule at the inventory_restock Lambda
resource "aws_cloudwatch_event_target" "inventory_restock" {
  rule = aws_cloudwatch_event_rule.inventory_restock.name
  arn  = var.inventory_restock_lambda_arn
}

# Allow EventBridge to invoke the Lambda
resource "aws_lambda_permission" "eventbridge_inventory_restock" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.inventory_restock_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inventory_restock.arn
}
