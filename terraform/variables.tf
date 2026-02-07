variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "api-health-monitor"
}

variable "alert_email" {
  description = "Email address for health check alerts"
  type        = string
}

variable "check_interval_minutes" {
  description = "How often to run health checks (in minutes)"
  type        = number
  default     = 1
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "sqs_visibility_timeout" {
  description = "SQS message visibility timeout in seconds"
  type        = number
  default     = 30
}
