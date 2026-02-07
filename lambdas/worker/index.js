const AWS = require('aws-sdk');
const axios = require('axios');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sns = new AWS.SNS();

const HEALTH_METRICS_TABLE = process.env.HEALTH_METRICS_TABLE;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

exports.handler = async (event) => {
  const results = [];
  
  for (const record of event.Records) {
    try {
      const monitor = JSON.parse(record.body);
      console.log(`Checking monitor: ${monitor.name}`);
      
      const startTime = Date.now();
      let health = {};
      
      try {
        // Make HTTP request
        const response = await axios({
          url: monitor.endpoint,
          method: monitor.method || 'GET',
          timeout: monitor.timeout || 5000,
          validateStatus: () => true  // Don't throw on non-2xx
        });
        
        const responseTime = Date.now() - startTime;
        
        health = {
          statusCode: response.status,
          responseTime,
          timestamp: Date.now(),
          isHealthy: response.status === monitor.expectedStatus
        };
        
      } catch (error) {
        health = {
          statusCode: 0,
          responseTime: Date.now() - startTime,
          timestamp: Date.now(),
          isHealthy: false,
          error: error.code === 'ECONNABORTED' ? 'Timeout' : error.message
        };
      }
      
      // Get previous state
      const previousState = await getPreviousState(monitor.monitorId);
      const previousFailures = previousState?.consecutiveFailures || 0;
      
      // Calculate consecutive failures with new logic
      let consecutiveFailures = 0;
      let state = 'HEALTHY';
      
      if (!health.isHealthy) {
        // On failure: increment but cap at threshold
        consecutiveFailures = Math.min(previousFailures + 1, monitor.thresholdCount);
        
        if (consecutiveFailures >= monitor.thresholdCount) {
          state = 'UNHEALTHY';
        } else {
          state = 'DEGRADED';
        }
      } else {
        // On success: decrement (gradual recovery)
        consecutiveFailures = Math.max(0, previousFailures - 1);
        
        if (consecutiveFailures === 0) {
          state = 'HEALTHY';
        } else {
          state = 'DEGRADED';  // Still recovering
        }
      }
      
      // Send alerts on state transitions
      // 1. Unhealthy alert: when first reaching threshold
      if (previousFailures < monitor.thresholdCount && consecutiveFailures === monitor.thresholdCount) {
        await sendUnhealthyAlert(monitor, consecutiveFailures);
      }
      
      // 2. Recovery alert: when returning to healthy (failures go from >0 to 0)
      if (previousFailures > 0 && consecutiveFailures === 0) {
        await sendRecoveryAlert(monitor);
      }
      
      // Store metrics
      await dynamodb.put({
        TableName: HEALTH_METRICS_TABLE,
        Item: {
          monitorId: monitor.monitorId,
          timestamp: Date.now(),
          state,
          consecutiveFailures,
          ...health,
          ttl: Math.floor(Date.now() / 1000) + (30 * 24 * 60 * 60)  // 30 days
        }
      }).promise();
      
      results.push({ monitorId: monitor.monitorId, success: true });
      
    } catch (error) {
      console.error('Error processing message:', error);
      results.push({ error: error.message });
      throw error;  // Let SQS retry
    }
  }
  
  return {
    statusCode: 200,
    body: JSON.stringify({ processed: results.length, results })
  };
};

async function getPreviousState(monitorId) {
  try {
    const result = await dynamodb.query({
      TableName: HEALTH_METRICS_TABLE,
      KeyConditionExpression: 'monitorId = :id',
      ExpressionAttributeValues: {
        ':id': monitorId
      },
      ScanIndexForward: false,
      Limit: 1
    }).promise();
    
    return result.Items?.[0];
  } catch (error) {
    console.error('Error getting previous state:', error);
    return null;
  }
}

async function sendUnhealthyAlert(monitor, failureCount) {
  const timestamp = new Date().toISOString();
  
  await sns.publish({
    TopicArn: SNS_TOPIC_ARN,
    Subject: `🔴 Alert: ${monitor.name} is UNHEALTHY`,
    Message: `Monitor: ${monitor.name}
Endpoint: ${monitor.endpoint}
Status: UNHEALTHY
Consecutive Failures: ${failureCount}
Time: ${timestamp}

This monitor has exceeded the failure threshold of ${monitor.thresholdCount}.
The endpoint is not responding as expected.`
  }).promise();
  
  console.log(`Unhealthy alert sent for monitor ${monitor.name}`);
}

async function sendRecoveryAlert(monitor) {
  const timestamp = new Date().toISOString();
  
  await sns.publish({
    TopicArn: SNS_TOPIC_ARN,
    Subject: `✅ Recovery: ${monitor.name} is HEALTHY`,
    Message: `Monitor: ${monitor.name}
Endpoint: ${monitor.endpoint}
Status: HEALTHY (Recovered)
Time: ${timestamp}

Good news! This monitor has recovered and is now responding normally.
All consecutive failures have been cleared.`
  }).promise();
  
  console.log(`Recovery alert sent for monitor ${monitor.name}`);
}
