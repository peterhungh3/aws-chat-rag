# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-redis-subnet-group"
  }
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.project_name}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = {
    Name = "${var.project_name}-redis-params"
  }
}

# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = var.redis_node_type
  num_cache_nodes      = var.redis_num_cache_nodes
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  port                 = 6379

  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  # Snapshot configuration
  snapshot_retention_limit = 5
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "mon:05:00-mon:07:00"

  # Notifications
  notification_topic_arn = ""

  tags = {
    Name = "${var.project_name}-redis"
  }
}

# Note: For production with high availability, consider using Redis Replication Group:
# resource "aws_elasticache_replication_group" "redis" {
#   replication_group_id       = "${var.project_name}-redis"
#   replication_group_description = "Redis cluster for work queue and caching"
#   engine                     = "redis"
#   engine_version             = "7.0"
#   node_type                  = var.redis_node_type
#   num_cache_clusters         = 2
#   parameter_group_name       = aws_elasticache_parameter_group.redis.name
#   port                       = 6379
#   
#   subnet_group_name          = aws_elasticache_subnet_group.redis.name
#   security_group_ids         = [aws_security_group.redis.id]
#   
#   automatic_failover_enabled = true
#   multi_az_enabled           = true
#   
#   at_rest_encryption_enabled = true
#   transit_encryption_enabled = true
#   
#   snapshot_retention_limit   = 5
#   snapshot_window            = "03:00-05:00"
#   maintenance_window         = "mon:05:00-mon:07:00"
#   
#   tags = {
#     Name = "${var.project_name}-redis"
#   }
# }

# Usage Notes:
# 
# 1. Work Queue (using Redis as backend for Celery or RQ):
#    - Python: pip install celery redis
#    - Configure: CELERY_BROKER_URL = f"redis://{redis_host}:{redis_port}/0"
#
# 2. Pub/Sub for SSE Notifications:
#    - Python: pip install redis aioredis
#    - Publisher (worker): redis_client.publish("notifications", json.dumps(message))
#    - Subscriber (FastAPI): async for message in pubsub.listen()
#
# 3. Caching:
#    - Store frequently accessed data
#    - Session management
#    - Rate limiting

