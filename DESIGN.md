# Design Documentation

## Architecture Overview

This system uses AWS serverless architecture for auto-scaling, high availability, and cost-effectiveness.

## Design Decisions

### 1. Why SQS Fan-out Pattern?

**Decision:** Use SQS between orchestrator and worker Lambdas

**Reasoning:**
- **Parallel Processing**: 100 monitors checked in ~10s vs 8+ minutes sequentially
- **Auto-scaling**: Lambda scales based on queue depth (up to 1000 concurrent)
- **Fault Tolerance**: Auto-retry failed checks (3 attempts)
- **Decoupling**: Orchestrator and workers are independent

**Trade-off:** Adds 1-2 seconds latency vs direct invocation

### 2. Why DynamoDB over RDS?

**Decision:** Use DynamoDB for both configs and metrics

**Reasoning:**
- **Performance**: <10ms latency vs 50ms+ for RDS
- **Scalability**: Auto-scales automatically
- **Cost**: Pay-per-request pricing
- **Serverless**: No database instances to manage

**Trade-off:** Less flexible querying than SQL

### 3. Why EventBridge Scheduling?

**Decision:** EventBridge triggers orchestrator every minute

**Reasoning:**
- Modern AWS service (CloudWatch Events is legacy)
- Simple cron-like scheduling
- Direct Lambda integration

### 4. Why SNS + SES?

**Decision:** Lambda → SNS → SES for alerts

**Reasoning:**
- **Fan-out**: Easy to add Slack, PagerDuty later
- **Decoupling**: Workers don't need SES permissions
- **Retry Logic**: SNS handles delivery retries

## Scalability Strategy

### Current (1-10K monitors)
- Orchestrator fetches all monitors
- Sends to SQS in batches of 10
- Workers process in parallel

### Large Scale (10K-100K monitors)
- Add DynamoDB pagination
- Request Lambda concurrency increase (1000 → 5000)
- Split into multiple queues by priority

### Bottlenecks & Mitigation

| Bottleneck | Solution |
|------------|----------|
| DynamoDB throttling | On-demand billing mode |
| Lambda concurrency | Request AWS increase |
| SES rate limits | Rate limit alerts (max 1 per 5min) |
| Orchestrator timeout | Use pagination |

## Failure Handling

### Target API Failures
- Worker detects failure
- Increments consecutiveFailures counter
- Alerts only after threshold (default: 3)

### Worker Lambda Crashes
- SQS visibility timeout (30s)
- Auto-retry up to 3 times
- Failed messages → Dead Letter Queue
- CloudWatch alarm notifies DevOps

### DynamoDB Throttling
- AWS SDK auto-retries with exponential backoff
- On-demand mode prevents throttling

## Trade-offs

### Latency vs Scalability
- Accept 1-2s queuing latency
- Gain ability to check 10K+ monitors in parallel

### Cost vs Performance
- DynamoDB on-demand: variable cost matches variable load
- $0.50/month @ 100 monitors vs $12/month @ 10K monitors

### Simplicity vs Flexibility
- Three separate Lambdas (API, Orchestrator, Worker)
- More functions but cleaner separation
- Easier to test, debug, and scale independently

## Future Improvements

1. **WebSocket real-time updates**
2. **Multi-channel notifications** (Slack, PagerDuty)
3. **Advanced health checks** (body validation, certificates)
4. **Historical analytics** with QuickSight
5. **Multi-region deployment**

## Assumptions

- Check frequency: 1 minute (configurable)
- Timeout: 5 seconds (configurable 1-30s)
- Threshold: 3 consecutive failures (configurable 1-10)
- Supported methods: GET, POST, HEAD
- Max monitors: 10,000 per account
- SSL/TLS: Accept all certificates

## Lessons Learned

### What Worked Well
- ✅ SQS fan-out dramatically improved scalability
- ✅ DynamoDB on-demand kept costs low
- ✅ Terraform made infrastructure reproducible
- ✅ Threshold logic prevented alert fatigue

### What I'd Do Differently
- Use Step Functions for orchestrator (better than Lambda)
- Add comprehensive monitoring from day 1
- Create Terraform modules earlier

## References

- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [SQS Fan-out Pattern](https://aws.amazon.com/blogs/compute/using-amazon-sqs-with-aws-lambda/)
