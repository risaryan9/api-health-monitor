# IAM Role for API Handler Lambda
resource "aws_iam_role" "api_handler_role" {
  name = "${var.project_name}-api-handler-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "api_handler_policy" {
  name = "${var.project_name}-api-handler-policy"
  role = aws_iam_role.api_handler_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.monitor_configs.arn
      }
    ]
  })
}

# API Handler Lambda Function
resource "aws_lambda_function" "api_handler" {
  filename      = "../.build/api-handler.zip"
  function_name = "${var.project_name}-api-handler"
  role          = aws_iam_role.api_handler_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = var.lambda_timeout
  memory_size   = 256
  
  environment {
    variables = {
      MONITOR_CONFIGS_TABLE = aws_dynamodb_table.monitor_configs.name
    }
  }
  
  # Placeholder - will be updated by install script
  source_code_hash = filebase64sha256("../lambdas/api-handler/index.js")
}

# IAM Role for Orchestrator Lambda
resource "aws_iam_role" "orchestrator_role" {
  name = "${var.project_name}-orchestrator-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "orchestrator_policy" {
  name = "${var.project_name}-orchestrator-policy"
  role = aws_iam_role.orchestrator_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.monitor_configs.arn,
          "${aws_dynamodb_table.monitor_configs.arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:SendMessageBatch"
        ]
        Resource = aws_sqs_queue.health_check_queue.arn
      }
    ]
  })
}

# Orchestrator Lambda Function
resource "aws_lambda_function" "orchestrator" {
  filename      = "../.build/orchestrator.zip"
  function_name = "${var.project_name}-orchestrator"
  role          = aws_iam_role.orchestrator_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = var.lambda_timeout
  memory_size   = 512
  
  environment {
    variables = {
      MONITOR_CONFIGS_TABLE = aws_dynamodb_table.monitor_configs.name
      SQS_QUEUE_URL         = aws_sqs_queue.health_check_queue.url
    }
  }
  
  source_code_hash = filebase64sha256("../lambdas/orchestrator/index.js")
}

# IAM Role for Worker Lambda
resource "aws_iam_role" "worker_role" {
  name = "${var.project_name}-worker-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "worker_policy" {
  name = "${var.project_name}-worker-policy"
  role = aws_iam_role.worker_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.health_metrics.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.health_check_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Worker Lambda Function
resource "aws_lambda_function" "worker" {
  filename      = "../.build/worker.zip"
  function_name = "${var.project_name}-worker"
  role          = aws_iam_role.worker_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  timeout       = var.lambda_timeout
  memory_size   = 256
  
  # Allow high concurrency
  reserved_concurrent_executions = 100
  
  environment {
    variables = {
      HEALTH_METRICS_TABLE = aws_dynamodb_table.health_metrics.name
      SNS_TOPIC_ARN        = aws_sns_topic.alerts.arn
    }
  }
  
  source_code_hash = filebase64sha256("../lambdas/worker/index.js")
}
