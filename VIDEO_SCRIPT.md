# API Health Monitor – Video Script (Part 1: Overview and Services)

**Total duration (this part):** ~5–6 minutes  
**Next part:** Diagram walkthrough (~4 minutes, separate)

---

## 1. Brief Overview (~50 seconds)

This project is an API health monitoring system that runs entirely on AWS using a serverless setup. You define monitors—each with a URL, expected HTTP status, check interval, and alert email. The system runs health checks on a schedule, stores the results, and sends email alerts when an endpoint goes down or when it recovers. There is a simple web UI hosted on S3 where you create and manage monitors. All infrastructure is defined in Terraform and deployed with a single install script, so you can bring the whole system up or tear it down in one go. No servers to manage—only Lambda functions, databases, queues, and a few other AWS services working together.

---

## 2. AWS Services and Terraform (30–40 seconds each)

### Terraform

Terraform is used here as infrastructure as code. Every AWS resource—Lambdas, API Gateway, DynamoDB tables, SQS, SNS, and so on—is defined in `.tf` files. We use the AWS provider and keep the config split by concern: one file for API Gateway, one for Lambdas, one for DynamoDB, and so on. Variables like region and alert email live in `terraform.tfvars`. After you run `terraform apply`, Terraform creates or updates the resources to match the code. The install script runs Terraform and then writes the outputs to a JSON file so the same script can deploy Lambda code and the frontend using those values, with no hardcoded IDs or URLs.

---

### Amazon S3

S3 hosts the static website for the UI. We use a single bucket with website hosting enabled and a policy that allows public read on the objects. The bucket name includes the project name and account ID so it is unique. The install script syncs the frontend files—HTML, CSS, and JavaScript—into this bucket. The JavaScript is configured with the API Gateway URL at deploy time by replacing a placeholder with the Terraform output. The website URL follows the format bucket name, then `s3-website`, then region, then `amazonaws.com`.

---

### API Gateway

API Gateway exposes a REST API with one stage, for example `prod`. The routes are: GET and POST on `/monitors` for listing and creating monitors, PATCH on `/monitors/{id}` for updating a monitor (for example setting it active or inactive), and DELETE on `/monitors/{id}` for deleting a monitor. Each route uses Lambda proxy integration, so the full request—path, method, body, and path parameters—is passed to a single Lambda function. CORS is set up so the S3-hosted frontend can call the API. The Lambda receives the path; it normalizes it so that both `/prod/monitors` and `/monitors` work, and for PATCH and DELETE it uses the path parameter `id` from API Gateway when available.

---

### AWS Lambda

There are three Lambda functions, all Node.js 18. The first is the API handler. It handles all API Gateway requests: it reads and writes the MonitorConfigs table in DynamoDB for CRUD, and it normalizes the path and uses path parameters so that routes work whether or not the path includes the stage name. The second is the orchestrator. It is triggered on a schedule by EventBridge. It queries DynamoDB for all active monitors using a GSI on `isActive`, and it sends each monitor as a JSON message to an SQS queue so workers can process them in parallel. The third is the worker. It is triggered by SQS. For each message it performs an HTTP request to the monitor’s URL, compares the status to the expected status, and then updates the HealthMetrics table with the result. It also maintains a consecutive failure count: failures increment up to the threshold, and successes decrement it. When the count first hits the threshold it sends an unhealthy alert via SNS; when the count returns to zero it sends a recovery alert. All three Lambdas bundle the AWS SDK and any other dependencies in the deployment zip because Node 18 does not include the AWS SDK in the runtime.

---

### DynamoDB

We use two tables. MonitorConfigs stores each monitor’s configuration: ID, name, endpoint, method, expected status, timeout, check interval, alert email, failure threshold, and an `isActive` flag. There is a global secondary index on `isActive` so the orchestrator can quickly query only active monitors. HealthMetrics stores the outcome of each health check: monitor ID, timestamp, state (healthy, degraded, or unhealthy), consecutive failure count, HTTP status and response time, and a TTL so old items are removed automatically. The table is keyed by monitor ID and timestamp so we can query the latest state for a monitor when the worker runs. Both tables use on-demand billing.

---

### Amazon SQS

SQS is the queue between the orchestrator and the worker. The orchestrator does not call the worker directly; it only sends one message per active monitor to the queue. Each message body is the full monitor object as JSON. The worker Lambda is connected to the queue via an event source mapping, so Lambda pulls messages in batches and invokes the worker once per batch. This gives decoupling and retries: if the worker fails, the message can be retried or go to a dead-letter queue. It also lets many worker invocations run in parallel so we can scale the number of monitors without changing the design.

---

### EventBridge (CloudWatch Events)

EventBridge runs the health-check cycle on a schedule. We use a rate expression—for example “every 1 minute”—so the rule fires at that interval. The rule’s target is the orchestrator Lambda, and there is a resource-based policy on the Lambda allowing EventBridge to invoke it. Each time the rule fires, the orchestrator runs once, queries active monitors from DynamoDB, and enqueues them to SQS. So the whole pipeline is driven by this single schedule; there is no per-monitor cron.

---

### Amazon SNS

SNS is used for alerts. We create one topic for alerts. The worker Lambda publishes to this topic when a monitor first becomes unhealthy (consecutive failures reach the threshold) and when it recovers (failures go back to zero). We add an email subscription to the topic with the user’s alert email as the endpoint. When you add an email subscription, SNS sends a confirmation email; the user must click the link to confirm. Until then, the subscription stays in “Pending confirmation” and no alerts are delivered. SNS uses SES under the hood to send those emails.

---

### Amazon SES

SES is used only to verify the alert email address. We register that address as an identity in SES so that SNS (and AWS in general) is allowed to send mail to it. Verification is done by the user clicking the link in the email SES sends. This is separate from SNS subscription confirmation: both the SNS confirmation and the SES verification are required for alerts to reach the inbox. The Terraform config has an SNS topic subscription with protocol email and the alert email as the endpoint, and a separate SES email identity for that address.

---

### CloudWatch

CloudWatch is used for logs and optionally for alarms. Each Lambda has a log group; the runtime sends logs there automatically. We can add alarms that trigger on metrics or errors and send to the same SNS topic if we want. The main use here is inspecting the orchestrator and worker logs to see how many monitors were queued, whether checks succeeded or failed, and whether alerts were sent.

---

### IAM

Each Lambda has its own IAM role and a policy that grants only what it needs. The API handler can read and write the MonitorConfigs table. The orchestrator can read MonitorConfigs and send messages to the SQS queue. The worker can read and write the HealthMetrics table, receive and delete messages from SQS, and publish to the SNS topic. All roles can write to CloudWatch Logs. There are no shared keys; everything uses short-lived credentials from the Lambda execution role.

---

## 3. Transition to Diagram

We have gone through each service and how it fits into the system. In the next part we will tie everything together with an architecture diagram and walk through the flow from the user creating a monitor to health checks running and alerts being sent.

---

*End of Part 1 script. Part 2: diagram explanation (~4 minutes) to be delivered separately.*
