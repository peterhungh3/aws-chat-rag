# Debugging Guide - 503 Service Temporarily Unavailable

## Quick Diagnosis Steps

### 1. Check ECS Service Status

```bash
aws ecs describe-services \
  --cluster aws-chat-rag-cluster \
  --services aws-chat-rag-service \
  --region us-east-2 \
  --query 'services[0].[status,runningCount,desiredCount]' \
  --output table
```

**Expected:**
- `status`: ACTIVE
- `runningCount`: 1 (or more)
- `desiredCount`: 1

**If runningCount is 0:** Tasks are failing to start

### 2. Check ECS Task Status

```bash
# List all tasks
aws ecs list-tasks \
  --cluster aws-chat-rag-cluster \
  --service-name aws-chat-rag-service \
  --region us-east-2

# Get task details (replace TASK_ID with output from above)
aws ecs describe-tasks \
  --cluster aws-chat-rag-cluster \
  --tasks TASK_ID \
  --region us-east-2 \
  --query 'tasks[0].[lastStatus,healthStatus,stoppedReason]' \
  --output table
```

**Check for:**
- `lastStatus`: RUNNING (not STOPPED)
- `healthStatus`: HEALTHY (or null if health checks not configured)
- `stoppedReason`: Should be null if running

### 3. Check CloudWatch Logs

```bash
# View recent logs
aws logs tail /ecs/aws-chat-rag --follow --region us-east-2

# Or view last 50 lines
aws logs tail /ecs/aws-chat-rag --since 10m --region us-east-2
```

**Look for:**
- Application startup errors
- Import errors
- Port binding issues
- Database connection errors

### 4. Check Target Group Health

```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --region us-east-2 \
  --query "TargetGroups[?contains(TargetGroupName, 'aws-chat-rag')].TargetGroupArn" \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-2
```

**Expected:**
- `State`: healthy
- `Reason`: Target.ResponseCodeMismatch or Target.FailedHealthChecks = problem

### 5. Check ALB Listener

```bash
# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region us-east-2 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'aws-chat-rag')].LoadBalancerArn" \
  --output text)

# Check listeners
aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region us-east-2
```

## Monitoring and Alarms

**New CloudWatch Alarms added for better observability:**

1. **ALB 5xx Errors (`aws-chat-rag-alb-5xx-errors`)**:
   - Triggers if there are **3 or more 5xx errors** in a 1-minute period.
   - Useful for catching brief outages or service unavailability.

2. **ALB Healthy Hosts Low (`aws-chat-rag-alb-healthy-hosts-low`)**:
   - Triggers if **HealthyHostCount < 1** for 1 minute.
   - **Crucial:** Catches when tasks are being killed/replaced and there are gaps with 0 healthy targets (causing 503s), even if the "UnhealthyHostCount" metric doesn't spike.

**GitHub Actions Health Check:**
The deployment workflow now includes a "Check service status" step that outputs:
- ECS service status (running count vs desired count)
- ALB target health status
- This runs automatically after deployment to verify success.

## Common Issues and Fixes

### Issue 1: Tasks Keep Stopping

**Symptoms:**
- `runningCount` = 0
- Tasks show as STOPPED

**Check:**
```bash
aws ecs describe-tasks \
  --cluster aws-chat-rag-cluster \
  --tasks $(aws ecs list-tasks --cluster aws-chat-rag-cluster --service-name aws-chat-rag-service --region us-east-2 --output text) \
  --region us-east-2 \
  --query 'tasks[0].stoppedReason' \
  --output text
```

**Common Reasons:**
- Container exited (check logs)
- Out of memory
- Health check failures
- Port binding issues

### Issue 2: Health Checks Failing

**Symptoms:**
- Tasks running but target unhealthy
- `Target.FailedHealthChecks` in target health

**Check health check configuration:**
```bash
aws elbv2 describe-target-groups \
  --region us-east-2 \
  --query "TargetGroups[?contains(TargetGroupName, 'aws-chat-rag')].[HealthCheckPath,HealthCheckIntervalSeconds,HealthyThresholdCount]" \
  --output table
```

**Verify:**
- Health check path: `/health` (should exist in FastAPI)
- Container port: 8000
- Application responds on `/health` endpoint

**Test health endpoint manually:**
```bash
# Get task IP (from ECS task details)
# Then test from within VPC or use port forwarding
curl http://TASK_IP:8000/health
```

### Issue 3: Security Group Issues

**Symptoms:**
- Tasks running but can't receive traffic

**Check security groups:**
```bash
# ECS tasks security group should allow traffic from ALB
aws ec2 describe-security-groups \
  --region us-east-2 \
  --filters "Name=tag:Name,Values=*ecs-tasks*" \
  --query "SecurityGroups[0].IpPermissions" \
  --output json
```

**Verify:**
- ALB security group can reach ECS tasks on port 8000
- ECS tasks security group allows inbound from ALB security group

### Issue 4: Container Image Issues

**Symptoms:**
- Tasks start then immediately stop
- Logs show import errors or missing files

**Check:**
```bash
# Verify image exists in ECR
aws ecr describe-images \
  --repository-name aws-chat-rag \
  --region us-east-2

# Check task definition uses correct image
aws ecs describe-task-definition \
  --task-definition aws-chat-rag-task \
  --region us-east-2 \
  --query 'taskDefinition.containerDefinitions[0].image' \
  --output text
```

### Issue 5: Database/Redis Connection Issues

**Symptoms:**
- Application starts but crashes on first request
- Logs show connection errors

**Check:**
- RDS endpoint is correct in task definition
- Redis endpoint is correct
- Security groups allow ECS → RDS and ECS → Redis
- Database password is correct in Secrets Manager

## Step-by-Step Debugging Workflow

1. **Check if tasks are running:**
   ```bash
   aws ecs describe-services --cluster aws-chat-rag-cluster --services aws-chat-rag-service --region us-east-2
   ```

2. **If tasks not running, check logs:**
   ```bash
   aws logs tail /ecs/aws-chat-rag --since 30m --region us-east-2
   ```

3. **If tasks running but unhealthy, check target health:**
   ```bash
   # Use commands from section 4 above
   ```

4. **Test health endpoint:**
   - Get task IP from ECS console or CLI
   - Test `/health` endpoint directly

5. **Check network connectivity:**
   - Verify security groups
   - Check route tables
   - Verify NAT Gateway (for outbound)

## Quick Fixes

### Restart ECS Service

```bash
aws ecs update-service \
  --cluster aws-chat-rag-cluster \
  --service aws-chat-rag-service \
  --force-new-deployment \
  --region us-east-2
```

### Check Recent Events

```bash
aws ecs describe-services \
  --cluster aws-chat-rag-cluster \
  --services aws-chat-rag-service \
  --region us-east-2 \
  --query 'services[0].events[0:5]' \
  --output table
```

### View Real-Time Logs

```bash
aws logs tail /ecs/aws-chat-rag --follow --region us-east-2
```

## Still Stuck?

1. Check AWS Console:
   - ECS → Clusters → aws-chat-rag-cluster → Services → aws-chat-rag-service
   - Look at "Events" tab for error messages
   - Check "Logs" tab for container logs

2. Verify Terraform outputs:
   ```bash
   cd terraform
   terraform output
   ```

3. Check all resources are created:
   ```bash
   terraform state list
   ```

