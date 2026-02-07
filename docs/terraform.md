# Terraform Documentation

## Overview

- Infrastructure is defined and managed with Terraform (HashiCorp).
- AWS provider version ~> 5.0; Terraform required_version >= 1.0.
- Single region deployment; region and project name are configurable via variables.

## Directory and Files

- **main.tf** – Provider config, required_version, data sources (caller identity, region).
- **variables.tf** – Input variables (aws_region, project_name, alert_email, check_interval_minutes, lambda_timeout, sqs_visibility_timeout).
- **outputs.tf** – Outputs for website_url, api_gateway_url, Lambda names, table names, SQS URL, bucket name.
- **terraform.tfvars.example** – Example values for variables; copy to terraform.tfvars and fill in.
- **api-gateway.tf** – REST API, /monitors and /monitors/{id} resources, methods, integrations, CORS, deployment, prod stage, Lambda permission.
- **lambda.tf** – IAM roles and policies for three Lambdas (api-handler, orchestrator, worker); function resources with env vars, timeouts, source_code_hash.
- **dynamodb.tf** – MonitorConfigs table (hash: monitorId, GSI ActiveMonitorsIndex on isActive); HealthMetrics table (hash: monitorId, range: timestamp, TTL).
- **sqs.tf** – SQS queue for health-check messages; Lambda event source mapping for worker.
- **s3.tf** – S3 bucket for website, website configuration (index/error), public access block, bucket policy for public read.
- **sns-ses.tf** – SNS topic for alerts; SNS email subscription (endpoint = alert_email); SES email identity for alert_email verification.
- **eventbridge.tf** – CloudWatch Events rule (schedule rate), target orchestrator Lambda, Lambda permission for events.
- **cloudwatch.tf** – Log groups for each Lambda; optional alarm and SNS alarm action.

## Key Resources

- **MonitorConfigs** – Stores monitor definitions (name, endpoint, method, expectedStatus, thresholdCount, alertEmail, etc.); GSI used by orchestrator to list active monitors.
- **HealthMetrics** – One item per health check (monitorId, timestamp, state, consecutiveFailures, statusCode, responseTime, isHealthy, ttl).
- **SQS** – Decouples orchestrator from worker; enables fan-out and retries.
- **API Gateway** – Single REST API with prod stage; proxy integration to api-handler Lambda.
- **Website URL** – Output uses format bucket.s3-website.region.amazonaws.com (dot before region).

## State and Workflow

- State is stored locally by default; for teams use a remote backend (e.g. S3 + DynamoDB).
- Typical workflow: terraform init, terraform plan, terraform apply; destroy via terraform destroy (after S3 buckets are emptied if applicable).
- Install script runs terraform init, plan, apply and writes outputs to terraform-outputs.json for use by bash scripts.
