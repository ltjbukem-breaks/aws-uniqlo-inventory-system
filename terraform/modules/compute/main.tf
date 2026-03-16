# IAM role that Lambda functions will assume
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Policy granting Lambda access to S3, Secrets Manager, and CloudWatch
resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_name}-${var.environment}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = [
          "${var.sales_data_bucket_arn}/*",
          "${var.product_updates_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [var.db_secret_arn]
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "${var.sales_data_bucket_arn}/*",
          "${var.product_updates_bucket_arn}/*",
          var.sales_data_bucket_arn,
          var.product_updates_bucket_arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = [
          var.sales_processor_dlq_arn,
          var.product_updater_dlq_arn,
          var.inventory_restock_dlq_arn
        ]
      }
    ]
  })
}

# Attach AWS managed policy for Lambda VPC access (allows Lambda to create network interfaces in VPC)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Zip the Lambda code
data "archive_file" "sales_processor" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/sales_processor"
  output_path = "${path.root}/../lambda/sales_processor.zip"
}

data "archive_file" "product_updater" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/product_updater"
  output_path = "${path.root}/../lambda/product_updater.zip"
}

data "archive_file" "inventory_restock" {
  type        = "zip"
  source_dir  = "${path.root}/../lambda/inventory_restock"
  output_path = "${path.root}/../lambda/inventory_restock.zip"
}

# Lambda functions
resource "aws_lambda_function" "sales_processor" {
  filename         = data.archive_file.sales_processor.output_path
  function_name    = "${var.project_name}-${var.environment}-sales-processor"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.sales_processor.output_base64sha256
  timeout          = 30


  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

    dead_letter_config {
    target_arn = var.sales_processor_dlq_arn
  }
}

resource "aws_lambda_function" "product_updater" {
  filename         = data.archive_file.product_updater.output_path
  function_name    = "${var.project_name}-${var.environment}-product-updater"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.product_updater.output_base64sha256
  timeout          = 30


  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

    dead_letter_config {
    target_arn = var.product_updater_dlq_arn
  }
}

resource "aws_lambda_function" "inventory_restock" {
  filename         = data.archive_file.inventory_restock.output_path
  function_name    = "${var.project_name}-${var.environment}-inventory-restock"
  role             = aws_iam_role.lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.inventory_restock.output_base64sha256
  timeout          = 60


  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

    dead_letter_config {
    target_arn = var.inventory_restock_dlq_arn
  }
}

# Allow S3 to invoke the Lambda functions
resource "aws_lambda_permission" "sales_processor" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sales_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.sales_data_bucket_name}"
}

resource "aws_lambda_permission" "product_updater" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.product_updater.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.product_updates_bucket_name}"
}

# S3 bucket notifications
resource "aws_s3_bucket_notification" "sales_data" {
  bucket = var.sales_data_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.sales_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.sales_processor]
}

resource "aws_s3_bucket_notification" "product_updates" {
  bucket = var.product_updates_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.product_updater.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.product_updater]
}
