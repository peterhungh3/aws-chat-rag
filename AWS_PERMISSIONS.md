# AWS Permissions Required

This document lists all AWS permissions needed to deploy and manage the AWS Chat RAG infrastructure.

## Overview

The AWS account/user running Terraform needs permissions to create and manage:
- VPC and networking resources
- ECS Fargate cluster and services
- Application Load Balancer
- RDS PostgreSQL database
- ElastiCache Redis cluster
- IAM roles and policies
- CloudWatch logs and alarms
- ECR container registry
- Secrets Manager
- Auto Scaling

## Recommended Approach

### Option 1: AWS Managed Policies (Recommended - easiest and most reliable)

Use AWS-managed policies which are pre-built and maintained by AWS. This avoids the 6144 character policy size limit.

**Best Practice: Attach to IAM Group (Recommended)**

Instead of attaching policies directly to users, attach them to a group. This makes permission management easier.

```bash
# Replace YOUR_GROUP_NAME with your IAM group name
GROUP_NAME="YOUR_GROUP_NAME"

# Attach all required policies to the group
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/ResourceGroupsandTagEditorFullAccess

# Verify policies are attached
aws iam list-attached-group-policies --group-name $GROUP_NAME

# Add inline policy for Application Auto Scaling (required for ECS auto-scaling tags)
cat > /tmp/autoscaling-policy.json << 'POLICY_EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "application-autoscaling:*",
      "Resource": "*"
    }
  ]
}
POLICY_EOF

aws iam put-group-policy \
  --group-name $GROUP_NAME \
  --policy-name ApplicationAutoScalingFullAccess \
  --policy-document file:///tmp/autoscaling-policy.json
```

**Alternative: Attach to IAM User directly**

If you don't have a group or prefer user-level permissions:

```bash
# Replace YOUR_USERNAME with your IAM username
USERNAME="YOUR_USERNAME"

# Attach all required policies to the user
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/ResourceGroupsandTagEditorFullAccess

# Verify policies are attached
aws iam list-attached-user-policies --user-name $USERNAME
```

**Managed Policies Included:**
- **AmazonEC2FullAccess**: VPC, subnets, NAT gateways, security groups, EIPs
- **AmazonECS_FullAccess**: ECS clusters, services, task definitions
- **AmazonRDSFullAccess**: PostgreSQL database management
- **AmazonElastiCacheFullAccess**: Redis cluster management
- **IAMFullAccess**: IAM roles, policies, OIDC provider
- **CloudWatchFullAccess**: Logs, alarms, metrics
- **SecretsManagerReadWrite**: Database password storage
- **ElasticLoadBalancingFullAccess**: Application Load Balancer
- **AmazonEC2ContainerRegistryFullAccess**: Docker container registry
- **ResourceGroupsandTagEditorFullAccess**: Tagging for Auto Scaling and other services

**Use when:** All deployments (development, testing, and production)

### Option 2: Administrator Access (Simplest - for learning only)
```bash
aws iam attach-user-policy --user-name YOUR_USERNAME --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

**Use when:** Learning, quick testing, or personal development environments

⚠️ **Not recommended for production** - too broad permissions

### Option 3: Custom Least Privilege Policy (Not Recommended - size limits)

**⚠️ WARNING:** This custom policy exceeds AWS's 6144 character limit and cannot be created as a single policy. Use **Option 1 (AWS Managed Policies)** instead.

The policy below is provided for reference only to show what permissions are needed:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VPCPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:DescribeVpcs",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:DescribeSubnets",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:DescribeInternetGateways",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:DescribeAddresses",
        "ec2:AssociateAddress",
        "ec2:DisassociateAddress",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway",
        "ec2:DescribeNatGateways",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeAccountAttributes"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecurityGroupPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
        "ec2:UpdateSecurityGroupRuleDescriptionsEgress"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSPermissions",
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeleteCluster",
        "ecs:DescribeClusters",
        "ecs:UpdateCluster",
        "ecs:CreateService",
        "ecs:DeleteService",
        "ecs:DescribeServices",
        "ecs:UpdateService",
        "ecs:RegisterTaskDefinition",
        "ecs:DeregisterTaskDefinition",
        "ecs:DescribeTaskDefinition",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ecs:TagResource",
        "ecs:UntagResource",
        "ecs:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRPermissions",
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:PutLifecyclePolicy",
        "ecr:GetLifecyclePolicy",
        "ecr:DeleteLifecyclePolicy",
        "ecr:PutImageTagMutability",
        "ecr:PutImageScanningConfiguration",
        "ecr:TagResource",
        "ecr:UntagResource",
        "ecr:ListTagsForResource",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ELBPermissions",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:ModifyTargetGroupAttributes",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:CreateRule",
        "elasticloadbalancing:DeleteRule",
        "elasticloadbalancing:DescribeRules",
        "elasticloadbalancing:ModifyRule",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:RemoveTags",
        "elasticloadbalancing:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "RDSPermissions",
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBInstance",
        "rds:DeleteDBInstance",
        "rds:DescribeDBInstances",
        "rds:ModifyDBInstance",
        "rds:CreateDBSubnetGroup",
        "rds:DeleteDBSubnetGroup",
        "rds:DescribeDBSubnetGroups",
        "rds:ModifyDBSubnetGroup",
        "rds:CreateDBParameterGroup",
        "rds:DeleteDBParameterGroup",
        "rds:DescribeDBParameterGroups",
        "rds:ModifyDBParameterGroup",
        "rds:DescribeDBParameters",
        "rds:ResetDBParameterGroup",
        "rds:AddTagsToResource",
        "rds:RemoveTagsFromResource",
        "rds:ListTagsForResource",
        "rds:CreateDBClusterParameterGroup",
        "rds:DescribeDBClusterParameterGroups",
        "rds:DescribeDBEngineVersions"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ElastiCachePermissions",
      "Effect": "Allow",
      "Action": [
        "elasticache:CreateCacheCluster",
        "elasticache:DeleteCacheCluster",
        "elasticache:DescribeCacheClusters",
        "elasticache:ModifyCacheCluster",
        "elasticache:CreateCacheSubnetGroup",
        "elasticache:DeleteCacheSubnetGroup",
        "elasticache:DescribeCacheSubnetGroups",
        "elasticache:ModifyCacheSubnetGroup",
        "elasticache:CreateCacheParameterGroup",
        "elasticache:DeleteCacheParameterGroup",
        "elasticache:DescribeCacheParameterGroups",
        "elasticache:ModifyCacheParameterGroup",
        "elasticache:DescribeCacheParameters",
        "elasticache:ResetCacheParameterGroup",
        "elasticache:AddTagsToResource",
        "elasticache:RemoveTagsFromResource",
        "elasticache:ListTagsForResource",
        "elasticache:DescribeEngineDefaultParameters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPermissions",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRoles",
        "iam:UpdateRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:ListRolePolicies",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:GetOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviders",
        "iam:UpdateOpenIDConnectProviderThumbprint",
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:ListOpenIDConnectProviderTags",
        "iam:PassRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchPermissions",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy",
        "logs:TagLogGroup",
        "logs:UntagLogGroup",
        "logs:ListTagsLogGroup",
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:PutMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "cloudwatch:TagResource",
        "cloudwatch:UntagResource",
        "cloudwatch:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsManagerPermissions",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue",
        "secretsmanager:UpdateSecret",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoScalingPermissions",
      "Effect": "Allow",
      "Action": [
        "application-autoscaling:RegisterScalableTarget",
        "application-autoscaling:DeregisterScalableTarget",
        "application-autoscaling:DescribeScalableTargets",
        "application-autoscaling:PutScalingPolicy",
        "application-autoscaling:DeleteScalingPolicy",
        "application-autoscaling:DescribeScalingPolicies",
        "application-autoscaling:DescribeScalingActivities"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TaggingPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "STSPermissions",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## Permission Breakdown by Service

### EC2 (VPC, Networking, Security Groups)
- **VPC**: Create, delete, describe, modify
- **Subnets**: Create, delete, describe, modify
- **Internet Gateway**: Create, delete, attach, detach
- **NAT Gateway**: Create, delete, describe
- **Elastic IPs**: Allocate, release, associate, disassociate
- **Route Tables**: Create, delete, modify routes, associate
- **Security Groups**: Create, delete, modify rules
- **Tags**: Create, delete, describe

### ECS (Container Orchestration)
- **Cluster**: Create, delete, describe, update
- **Service**: Create, delete, describe, update
- **Task Definition**: Register, deregister, describe
- **Tasks**: List, describe
- **Tags**: Tag, untag, list

### ECR (Container Registry)
- **Repository**: Create, delete, describe
- **Lifecycle Policy**: Put, get, delete
- **Images**: Push, pull, scan configuration
- **Tags**: Tag, untag, list

### ELB (Load Balancer)
- **Load Balancer**: Create, delete, describe, modify
- **Target Group**: Create, delete, describe, modify, register targets
- **Listener**: Create, delete, describe, modify
- **Rules**: Create, delete, describe, modify
- **Tags**: Add, remove, describe

### RDS (Database)
- **DB Instance**: Create, delete, describe, modify
- **Subnet Group**: Create, delete, describe, modify
- **Parameter Group**: Create, delete, describe, modify, reset
- **Tags**: Add, remove, list

### ElastiCache (Redis)
- **Cache Cluster**: Create, delete, describe, modify
- **Subnet Group**: Create, delete, describe, modify
- **Parameter Group**: Create, delete, describe, modify, reset
- **Tags**: Add, remove, list

### IAM (Identity & Access)
- **Roles**: Create, delete, get, list, update
- **Policies**: Put, delete, get, list, attach, detach
- **OIDC Provider**: Create, delete, get, list, update
- **PassRole**: Required for ECS task execution roles

### CloudWatch (Monitoring)
- **Log Groups**: Create, delete, describe, put retention
- **Alarms**: Put, delete, describe
- **Metrics**: Put, get statistics, list
- **Tags**: Tag, untag, list

### Secrets Manager
- **Secrets**: Create, delete, describe, get value, put value, update
- **Tags**: Tag, untag, list

### Application Auto Scaling
- **Scalable Targets**: Register, deregister, describe
- **Scaling Policies**: Put, delete, describe
- **Scaling Activities**: Describe

## Quick Setup Guide

### Step 1: Choose Setup Method

**Method A: Using IAM Group (Recommended - Best Practice)**

1. Find your IAM group (if you're in one):
   ```bash
   aws iam list-groups-for-user --user-name $(aws iam get-user --query "User.UserName" --output text)
   ```

2. Attach policies to the group (requires admin temporarily):
   ```bash
   GROUP_NAME="YOUR_GROUP_NAME"  # Replace with your group name
   
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
   aws iam attach-group-policy --group-name $GROUP_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
   ```

3. Verify:
   ```bash
   aws iam list-attached-group-policies --group-name $GROUP_NAME
   ```

**Method B: Using IAM User (Alternative)**

1. Find your IAM username:
   ```bash
   aws iam get-user --query "User.UserName" --output text
   ```

2. Attach policies to your user:
   ```bash
   USERNAME="YOUR_USERNAME"  # Replace with your username
   
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
   aws iam attach-user-policy --user-name $USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
   ```

3. Verify:
   ```bash
   aws iam list-attached-user-policies --user-name $USERNAME
   ```

### Step 2: Test Permissions

```bash
# Test EC2 access
aws ec2 describe-vpcs

# Expected: List of VPCs in your account
```

### Alternative: Use IAM Role (For CI/CD or temporary access)

1. Create an IAM role for Terraform
2. Attach the same managed policies to the role
3. Assume the role when running Terraform:
   ```bash
   aws sts assume-role --role-arn arn:aws:iam::ACCOUNT:role/TerraformRole --role-session-name terraform
   ```

## Verification

After setting up permissions, verify with:

```bash
# Test basic access
aws sts get-caller-identity

# Test VPC access
aws ec2 describe-vpcs

# Test ECS access
aws ecs list-clusters

# Test RDS access
aws rds describe-db-instances
```

## Troubleshooting

### Common Permission Errors

**Error: "User is not authorized to perform: ec2:CreateVpc"**
- **Fix**: Add EC2 VPC permissions to your policy

**Error: "User is not authorized to perform: iam:CreateRole"**
- **Fix**: Add IAM permissions, especially `iam:CreateRole` and `iam:PassRole`

**Error: "User is not authorized to perform: ecs:CreateService"**
- **Fix**: Add ECS service creation permissions

**Error: "User is not authorized to perform: iam:PassRole"**
- **Fix**: Add `iam:PassRole` permission for ECS task execution roles

### Least Privilege Best Practices

1. **Start with AdministratorAccess** for initial testing
2. **Monitor CloudTrail** to see what permissions are actually used
3. **Create custom policy** based on actual usage
4. **Use resource-level permissions** where possible (e.g., restrict to specific VPCs)
5. **Review and tighten** permissions regularly

## Additional Notes

- **OIDC Provider**: Requires IAM permissions to create/manage OIDC providers
- **PassRole**: Required when ECS tasks need to assume IAM roles
- **Tags**: Most resources require tagging permissions
- **Cross-Service**: Some operations require permissions across multiple services (e.g., ECS + ECR + IAM)

## Security Recommendations

1. **Never use AdministratorAccess in production**
2. **Use IAM roles instead of users** when possible
3. **Enable MFA** for IAM users
4. **Rotate access keys** regularly
5. **Use CloudTrail** to audit all API calls
6. **Review permissions** quarterly
7. **Use resource-level permissions** to limit scope

