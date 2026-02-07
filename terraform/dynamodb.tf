# Monitor Configurations Table
resource "aws_dynamodb_table" "monitor_configs" {
  name           = "MonitorConfigs"
  billing_mode   = "PAY_PER_REQUEST"  # Auto-scaling, no capacity planning
  hash_key       = "monitorId"
  
  attribute {
    name = "monitorId"
    type = "S"
  }
  
  attribute {
    name = "isActive"
    type = "S"
  }
  
  # GSI for querying active monitors
  global_secondary_index {
    name            = "ActiveMonitorsIndex"
    hash_key        = "isActive"
    projection_type = "ALL"
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Name = "${var.project_name}-monitor-configs"
  }
}

# Health Metrics Table
resource "aws_dynamodb_table" "health_metrics" {
  name           = "HealthMetrics"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "monitorId"
  range_key      = "timestamp"
  
  attribute {
    name = "monitorId"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "N"
  }
  
  # TTL to auto-delete old metrics (optional, keeps last 30 days)
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  point_in_time_recovery {
    enabled = true
  }
  
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Name = "${var.project_name}-health-metrics"
  }
}
