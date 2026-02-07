# Lambda Functions Documentation

## Overview

- Three Node.js 18.x Lambda functions: api-handler, orchestrator, worker.
- All depend on aws-sdk (v2) in package.json; worker also uses axios. Node 18 runtime does not bundle aws-sdk.
- Deployed as zip files containing index.js and node_modules (built by install script).

## API Handler (api-handler)

- **Purpose:** REST API for monitor CRUD; invoked by API Gateway.
- **Routes:** GET /monitors (list), POST /monitors (create), DELETE /monitors/{id} (delete). Path is normalized to strip optional stage prefix (e.g. /prod).
- **Environment:** MONITOR_CONFIGS_TABLE.
- **Dependencies:** aws-sdk, uuid.
- **Behavior:** Creates monitors with monitorId (UUID), isActive 'true'; delete removes item from MonitorConfigs only. Path parsing uses last segment for monitor ID so it works with or without /prod prefix.

## Orchestrator (orchestrator)

- **Purpose:** Runs on a schedule (EventBridge); queues all active monitors for health checks.
- **Trigger:** EventBridge rule (rate in minutes from check_interval_minutes).
- **Environment:** MONITOR_CONFIGS_TABLE, SQS_QUEUE_URL.
- **Dependencies:** aws-sdk.
- **Behavior:** Queries MonitorConfigs via ActiveMonitorsIndex (isActive = 'true'); sends each monitor as JSON to SQS in batches of 10. No health check logic; only enqueues work.

## Worker (worker)

- **Purpose:** Consumes SQS messages; performs HTTP health check per monitor; updates HealthMetrics and sends SNS alerts.
- **Trigger:** SQS queue (event source mapping).
- **Environment:** HEALTH_METRICS_TABLE, SNS_TOPIC_ARN.
- **Dependencies:** aws-sdk, axios.
- **Behavior:**
  - Per message: parse monitor, HTTP request (method, timeout, expectedStatus), compute isHealthy.
  - Load previous state from HealthMetrics (latest item by monitorId).
  - Failure count: on failure increment and cap at thresholdCount; on success decrement to minimum 0 (gradual recovery).
  - States: HEALTHY (failures 0), DEGRADED (0 < failures < threshold), UNHEALTHY (failures == threshold).
  - Send unhealthy SNS alert when failures first reach threshold; send recovery SNS alert when failures return to 0 from above 0.
  - Write one HealthMetrics item per run (monitorId, timestamp, state, consecutiveFailures, statusCode, responseTime, isHealthy, ttl).
- **Concurrency:** Reserved concurrent executions 100 (configurable in lambda.tf).

## Packaging and Deployment

- Each Lambda has a package.json with dependencies; install script runs npm install (production) in each directory, then zips contents (including node_modules) to .build/<name>.zip.
- Terraform references .build/*.zip for initial deploy; install script updates code with aws lambda update-function-code after apply.
- Ensure all three package.json files include aws-sdk; worker must also include axios.
