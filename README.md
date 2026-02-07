# API Health Monitor

**Demo video (part 1):** [Placeholder link to drive demo video 1]  
**Demo video (part 2):** [Placeholder link to drive demo video 2]

---

## Overview

- Self-hosted API health monitoring system built on AWS serverless components.
- Users create monitors (endpoint URL, method, expected status, timeout, check interval, alert email, failure threshold).
- System runs periodic health checks, stores metrics, and sends email alerts when a monitor becomes unhealthy or recovers.
- All infrastructure is defined in Terraform; deployment and teardown are automated with bash scripts.

---

## Table of Contents

- [Architecture](#architecture)
- [Key Design Decisions](#key-design-decisions)
- [Prerequisites](#prerequisites)
- [Installation Instructions](#installation-instructions)
- [Troubleshooting Guide](#troubleshooting-guide)
- [Recap](#recap)
- [Credits](#credits)

**Other documentation:**

- [Terraform](docs/terraform.md) – Infrastructure as code, resources, and outputs.
- [Lambda functions](docs/lambdas.md) – API handler, orchestrator, and worker.
- [Bash scripts](docs/bash-scripts.md) – install.sh and shutdown.sh.

---

## Architecture

- **Frontend:** Static site (HTML/CSS/JS) hosted on S3; uses API Gateway base URL for all API calls.
- **API:** API Gateway REST API (prod stage) with proxy integration to the api-handler Lambda; routes: GET/POST /monitors, DELETE /monitors/{id}.
- **Data:** DynamoDB – MonitorConfigs (monitor definitions), HealthMetrics (per-check results with state and consecutive failure count).
- **Scheduling:** EventBridge rule triggers the orchestrator Lambda on a fixed rate (e.g. every 1 minute).
- **Queue:** SQS queue holds one message per monitor per run; worker Lambda consumes messages.
- **Workers:** Worker Lambda performs HTTP checks, updates HealthMetrics, and sends SNS alerts (unhealthy when threshold reached, recovery when back to healthy).
- **Alerts:** SNS topic with email subscription (alert email); SES used to verify the email address. User must confirm SNS subscription in the email.

---

## Key Design Decisions

- **Single EventBridge schedule:** One rule drives all monitors; orchestrator queries active monitors and fans out to SQS for parallel worker execution.
- **Failure and recovery logic:** Consecutive failures increment and cap at threshold; consecutive successes decrement to zero. Unhealthy alert when threshold is first reached; recovery alert when failures return to zero.
- **Path normalization in API handler:** Request path may include stage (e.g. /prod/monitors); handler strips optional first segment so routes work with or without it; DELETE uses last path segment as monitor ID.
- **Terraform outputs as source of truth:** Install script reads Lambda names, bucket name, API URL from terraform output -json; no hardcoded resource names in scripts.
- **Node 18 and aws-sdk:** All Lambdas declare aws-sdk (and worker declares axios) in package.json and ship node_modules in the zip; runtime does not bundle aws-sdk.

---

## Prerequisites

- AWS account with credentials configured (`aws configure`).
- Terraform >= 1.0.
- Node.js >= 18 and npm.
- Bash shell.
- zip (for packaging Lambdas).
- Optional: jq (for reliable parsing of Terraform outputs in install script).

---

## Installation Instructions

- Clone the repository and from the project root run: `chmod +x *.sh` then `./install.sh`.
- Script will: check prerequisites; prompt for alert email and region if terraform.tfvars is missing; package all three Lambdas; run Terraform init, plan, apply; deploy Lambda code; deploy frontend to S3; print website URL, API URL, and next steps.
- After install: open the website URL; create a monitor; confirm SNS subscription and SES verification for the alert email; wait for the first health checks (interval depends on check_interval_minutes).
- To destroy all resources: run `./shutdown.sh` and type `yes` when prompted.

---

## Troubleshooting Guide

- **Lambda "Cannot find module 'aws-sdk'":** Add aws-sdk to the Lambda’s package.json, run npm install in that Lambda directory, rebuild the zip, and redeploy with `aws lambda update-function-code`. See [Lambda functions](docs/lambdas.md).
- **HealthMetrics not updating:** Confirm orchestrator and worker have aws-sdk in package.json and are deployed; check CloudWatch logs for orchestrator (should log "Found N active monitors") and worker (should log "Checking monitor: ..."); ensure EventBridge rule is enabled and SQS queue is attached to worker.
- **SNS subscription "Pending confirmation":** Confirm the SNS subscription by opening the email from AWS SNS and clicking the confirmation link; SES verification is separate from SNS subscription confirmation.
- **API 403 or 404:** Use the full API Gateway URL including the stage (e.g. https://xxx.execute-api.region.amazonaws.com/prod); frontend should use the Terraform output api_gateway_url without appending /prod again.
- **DELETE monitor not removing:** Ensure API handler is redeployed with path normalization and monitor ID from last path segment; check Lambda logs for the received path and extracted ID.
- **Website URL wrong format:** Terraform output website_url must use format bucket.s3-website.region.amazonaws.com (dot before region); fix in outputs.tf if it used a hyphen.
- **Empty Lambda names in install script:** Ensure terraform-outputs.json exists after apply; install script uses get_tf_output (jq or python3); install jq or fix JSON parsing if values are empty.

---

## Recap

- Monitors are stored in DynamoDB; health checks run on a schedule and results are written to HealthMetrics.
- Alerts are sent via SNS (email) when a monitor hits the failure threshold and when it recovers to zero failures.
- Deleting a monitor from the UI removes it from MonitorConfigs; no further checks or alerts are queued for it.
- Full deployment and teardown are automated via install.sh and shutdown.sh; details are in the linked docs.

---

## Credits

- **By:** [Abhiram Rakesh](https://www.linkedin.com/in/abhiram-rakesh/)
- **For:** Hyperverge
