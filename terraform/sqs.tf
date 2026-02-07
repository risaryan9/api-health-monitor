# Main health check queue
resource "aws_sqs_queue" "health_check_queue" {
  name                       = "${var.project_name}-health-check-queue"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = 86400  # 1 day
  max_message_size          = 262144  # 256 KB
  delay_seconds             = 0
  receive_wait_time_seconds = 0
  
  # Enable dead letter queue
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.health_check_dlq.arn
    maxReceiveCount     = 3
  })
  
  tags = {
    Name = "${var.project_name}-health-check-queue"
  }
}

# Dead Letter Queue for failed messages
resource "aws_sqs_queue" "health_check_dlq" {
  name                      = "${var.project_name}-health-check-dlq"
  message_retention_seconds = 1209600  # 14 days
  
  tags = {
    Name = "${var.project_name}-health-check-dlq"
  }
}

# Allow Lambda to receive messages
resource "aws_lambda_event_source_mapping" "worker_sqs" {
  event_source_arn = aws_sqs_queue.health_check_queue.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 10
  enabled          = true
}
