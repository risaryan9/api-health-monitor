output "website_url" {
  description = "URL of the static website"
  value       = "http://${aws_s3_bucket.website.bucket}.s3-website-${data.aws_region.current.name}.amazonaws.com"
}

output "website_bucket_name" {
  description = "Name of the S3 bucket hosting the website"
  value       = aws_s3_bucket.website.id
}

output "api_gateway_url" {
  description = "URL of the API Gateway"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "api_handler_function_name" {
  description = "Name of the API Handler Lambda function"
  value       = aws_lambda_function.api_handler.function_name
}

output "orchestrator_function_name" {
  description = "Name of the Orchestrator Lambda function"
  value       = aws_lambda_function.orchestrator.function_name
}

output "worker_function_name" {
  description = "Name of the Worker Lambda function"
  value       = aws_lambda_function.worker.function_name
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.health_check_queue.url
}

output "monitor_configs_table" {
  description = "Name of the MonitorConfigs DynamoDB table"
  value       = aws_dynamodb_table.monitor_configs.name
}

output "health_metrics_table" {
  description = "Name of the HealthMetrics DynamoDB table"
  value       = aws_dynamodb_table.health_metrics.name
}
