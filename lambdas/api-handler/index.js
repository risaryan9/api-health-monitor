const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();
const { v4: uuidv4 } = require('uuid');

const MONITOR_CONFIGS_TABLE = process.env.MONITOR_CONFIGS_TABLE;

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
  'Content-Type': 'application/json'
};

exports.handler = async (event) => {
  console.log('Event:', JSON.stringify(event, null, 2));
  
  const path = event.path;
  const method = event.httpMethod;
  
  try {
    // GET /monitors - List all monitors
    if (path === '/monitors' && method === 'GET') {
      const result = await dynamodb.scan({
        TableName: MONITOR_CONFIGS_TABLE
      }).promise();
      
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({
          monitors: result.Items || []
        })
      };
    }
    
    // POST /monitors - Create new monitor
    if (path === '/monitors' && method === 'POST') {
      const body = JSON.parse(event.body);
      
      // Validate required fields
      if (!body.name || !body.endpoint || !body.alertEmail) {
        return {
          statusCode: 400,
          headers,
          body: JSON.stringify({ error: 'Missing required fields' })
        };
      }
      
      const monitor = {
        monitorId: uuidv4(),
        name: body.name,
        endpoint: body.endpoint,
        method: body.method || 'GET',
        expectedStatus: body.expectedStatus || 200,
        timeout: body.timeout || 5000,
        checkInterval: body.checkInterval || 60,
        alertEmail: body.alertEmail,
        thresholdCount: body.thresholdCount || 3,
        isActive: 'true',
        createdAt: Date.now(),
        updatedAt: Date.now()
      };
      
      await dynamodb.put({
        TableName: MONITOR_CONFIGS_TABLE,
        Item: monitor
      }).promise();
      
      return {
        statusCode: 201,
        headers,
        body: JSON.stringify(monitor)
      };
    }
    
    // DELETE /monitors/{id}
    if (path.startsWith('/monitors/') && method === 'DELETE') {
      const monitorId = path.split('/')[2];
      
      await dynamodb.delete({
        TableName: MONITOR_CONFIGS_TABLE,
        Key: { monitorId }
      }).promise();
      
      return {
        statusCode: 200,
        headers,
        body: JSON.stringify({ message: 'Monitor deleted' })
      };
    }
    
    return {
      statusCode: 404,
      headers,
      body: JSON.stringify({ error: 'Not found' })
    };
    
  } catch (error) {
    console.error('Error:', error);
    return {
      statusCode: 500,
      headers,
      body: JSON.stringify({ error: error.message })
    };
  }
};
