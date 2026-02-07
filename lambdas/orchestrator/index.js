const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const sqs = new AWS.SQS();

const MONITOR_CONFIGS_TABLE = process.env.MONITOR_CONFIGS_TABLE;
const SQS_QUEUE_URL = process.env.SQS_QUEUE_URL;

exports.handler = async (event) => {
  console.log('Starting health check orchestration');
  
  try {
    // Fetch all active monitors
    const result = await dynamodb.query({
      TableName: MONITOR_CONFIGS_TABLE,
      IndexName: 'ActiveMonitorsIndex',
      KeyConditionExpression: 'isActive = :active',
      ExpressionAttributeValues: {
        ':active': 'true'
      }
    }).promise();
    
    const monitors = result.Items || [];
    console.log(`Found ${monitors.length} active monitors`);
    
    if (monitors.length === 0) {
      return { statusCode: 200, message: 'No active monitors' };
    }
    
    // Send monitors to SQS in batches of 10
    for (let i = 0; i < monitors.length; i += 10) {
      const batch = monitors.slice(i, i + 10);
      
      const entries = batch.map((monitor, index) => ({
        Id: `${i + index}`,
        MessageBody: JSON.stringify(monitor)
      }));
      
      await sqs.sendMessageBatch({
        QueueUrl: SQS_QUEUE_URL,
        Entries: entries
      }).promise();
      
      console.log(`Sent batch of ${entries.length} monitors to SQS`);
    }
    
    return {
      statusCode: 200,
      message: `Queued ${monitors.length} monitors for health checks`
    };
    
  } catch (error) {
    console.error('Error:', error);
    throw error;
  }
};
