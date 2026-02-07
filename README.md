# API Health Monitoring System

A self-hosted, scalable API health monitoring system built with AWS serverless architecture.

## 🏗️ Architecture

```
User → S3 Website → API Gateway → Lambda (API) → DynamoDB (Configs)
                                                       
EventBridge (Scheduler) → Lambda (Orchestrator) → SQS Queue
                                                       ↓
                                        Lambda (Worker) → Health Checks
                                                       ↓
                                        DynamoDB (Metrics) + SNS → SES
```

## 🚀 Quick Start

### Prerequisites
- AWS Account with configured credentials (`aws configure`)
- Terraform >= 1.0
- Node.js >= 18
- Bash shell

### Installation

```bash
git clone <your-repo-url>
cd api-health-monitor
chmod +x *.sh
./install.sh
```

Installation takes ~5-7 minutes and will:
1. Deploy AWS infrastructure
2. Package and deploy Lambda functions  
3. Deploy frontend website
4. Configure SES email verification

### Cleanup

```bash
./shutdown.sh
```

## 📖 Usage

1. Open the website URL provided after installation
2. Create a monitor with:
   - Name, endpoint URL, expected status
   - Timeout, check interval, failure threshold
   - Alert email address
3. Wait 1-2 minutes for first health check
4. Receive email alerts when APIs go down

### Test Endpoints

```
✅ Always UP:    https://httpstat.us/200
❌ Always DOWN:  https://httpstat.us/500
⏱️  Slow (2s):    https://httpstat.us/200?sleep=2000
```

## 🏛️ Architecture Details

### Key Components
- **S3**: Static website hosting
- **API Gateway + Lambda**: RESTful API for CRUD  
- **DynamoDB**: Monitor configs and metrics storage
- **EventBridge**: Scheduled health check triggers (every 1 min)
- **SQS**: Fan-out pattern for parallel execution
- **Lambda Workers**: Execute health checks concurrently
- **SNS + SES**: Email notifications

### Scalability

| Monitors | Processing Time | Workers |
|----------|----------------|---------|
| 100      | ~5 seconds     | 10-20   |
| 1,000    | ~15 seconds    | 100-200 |
| 10,000   | ~30 seconds    | 500+    |

### Cost Estimate

For 1,000 monitors checked every minute: **~$12/month**

## 🔧 Configuration

Edit `terraform/terraform.tfvars`:

```hcl
aws_region = "us-east-1"
project_name = "api-health-monitor"
alert_email = "your-email@example.com"
check_interval_minutes = 1
lambda_timeout = 30
```

## 📊 Monitoring

```bash
# View Lambda logs
aws logs tail /aws/lambda/api-health-monitor-worker --follow

# List monitors
aws dynamodb scan --table-name MonitorConfigs

# Check SQS queue
aws sqs get-queue-attributes --queue-url <url> --attribute-names All
```

## 📁 Project Structure

```
api-health-monitor/
├── README.md              # This file
├── DESIGN.md              # Architecture decisions
├── install.sh             # Automated deployment
├── shutdown.sh            # Cleanup script
├── terraform/             # Infrastructure as Code
│   ├── main.tf
│   ├── lambda.tf
│   ├── dynamodb.tf
│   ├── sqs.tf
│   ├── api-gateway.tf
│   └── ...
├── lambdas/               # Lambda functions
│   ├── api-handler/       # CRUD API
│   ├── orchestrator/      # Health check scheduler  
│   └── worker/            # Health check executor
└── frontend/              # Static website
    ├── index.html
    ├── style.css
    └── app.js
```

## 🛠️ Troubleshooting

**Email not received?**
- Check spam folder
- Verify email in AWS SES console

**Monitor not checking?**
- Check EventBridge rule is enabled
- View orchestrator logs

**Terraform errors?**
- Run `./shutdown.sh` first
- Then `./install.sh` again

## 📄 License

MIT License - See LICENSE file

## 🙏 Acknowledgments

Built for DevOps Internship Assignment 2026
