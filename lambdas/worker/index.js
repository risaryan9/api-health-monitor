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
      
      // Calculate consecutive failures
      let consecutiveFailures = previousState?.consecutiveFailures || 0;
      let state = 'HEALTHY';
      
      if (!health.isHealthy) {
        consecutiveFailures++;
        if (consecutiveFailures >= monitor.thresholdCount) {
          state = 'UNHEALTHY';
        } else {
          state = 'DEGRADED';
        }
      } else {
        consecutiveFailures = 0;
      }
      
      // Detect state change
      if (previousState && state !== previousState.state && state === 'UNHEALTHY') {
        await sendAlert(monitor, previousState.state, state, consecutiveFailures);
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

async function sendAlert(monitor, oldState, newState, failureCount) {
  const message = {
    monitorName: monitor.name,
    endpoint: monitor.endpoint,
    oldState,
    newState,
    failureCount,
    timestamp: new Date().toISOString()
  };
  
  await sns.publish({
    TopicArn: SNS_TOPIC_ARN,
    Subject: `🔴 Alert: ${monitor.name} is ${newState}`,
    Message: `Monitor: ${monitor.name}
Endpoint: ${monitor.endpoint}
Status: ${oldState} → ${newState}
Consecutive Failures: ${failureCount}
Time: ${message.timestamp}

This monitor has exceeded the failure threshold of ${monitor.thresholdCount}.`
  }).promise();
  
  console.log(`Alert sent for monitor ${monitor.name}`);
}
