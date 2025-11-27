# Deployment Guide

This guide walks you through deploying the AWS Chat RAG application from scratch.

## Prerequisites

Before you begin, ensure you have:

- AWS Account with appropriate permissions (see [AWS_PERMISSIONS.md](AWS_PERMISSIONS.md) for detailed list)
- AWS CLI installed and configured
- Terraform >= 1.0 installed
- Docker installed (for local testing)
- GitHub account
- Git installed

### Verify Prerequisites

Run these commands to verify your environment:

```bash
# Check AWS CLI is installed
aws --version
# Expected output: aws-cli/2.x.x Python/3.x.x ...

# Check AWS CLI is configured (may prompt for credentials if not configured)
aws sts get-caller-identity
# Expected output (if configured):
# {
#     "UserId": "AIDA...",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
# 
# If you see "Unable to locate credentials" or no output:
# → Run: aws configure (see below)

# Check Terraform version (need >= 1.0)
terraform --version
# Expected: Terraform v1.0.0 or higher

# Check Docker is installed and running
docker --version
docker ps
# Expected: Docker version and list of running containers (or empty)

# Check Git is installed
git --version
# Expected: git version 2.x.x or higher
```

**If any command fails:**
- AWS CLI: [Install guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- Terraform: [Install guide](https://developer.hashicorp.com/terraform/downloads)
- Docker: [Install guide](https://docs.docker.com/get-docker/)
- Git: [Install guide](https://git-scm.com/downloads)

**Configure AWS CLI** (if `aws sts get-caller-identity` returns nothing or an error):

```bash
aws configure
# You'll be prompted for:
# AWS Access Key ID: [Enter your access key]
# AWS Secret Access Key: [Enter your secret key]
# Default region name: us-east-2
# Default output format: json

# Verify configuration worked:
aws sts get-caller-identity
# Should now show your AWS account details
```

**Getting AWS Credentials:**
1. Log into AWS Console → IAM → Users → Your User → Security Credentials
2. Create Access Key → Download or copy Access Key ID and Secret Access Key
3. Use these in `aws configure`

**Note:** Never share your AWS credentials or commit them to version control!

## Step 1: Set up AWS OIDC Provider (One-time setup)

First, create the OIDC provider in AWS IAM for GitHub Actions:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bf075b76b750d4f2df264fcd \
  --region us-east-2
```

## Step 2: Configure Terraform Variables

1. Copy the example variables file (paste both lines together):

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` and update the following values:

```hcl
# IMPORTANT: Change these values
db_password = "YOUR_SECURE_PASSWORD_HERE"  # Use a strong password!
github_repo = "your-github-username/aws-chat-rag"  # Your GitHub repo
```

**Security Note**: Never commit `terraform.tfvars` to version control (it's in `.gitignore`).

## Step 3: Deploy Infrastructure

Initialize and apply Terraform configuration (you can paste the entire block):

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the planned changes
terraform plan

# Apply the infrastructure (this will take 10-15 minutes)
terraform apply
```

**Note:** Type `yes` when prompted by `terraform apply`.

## Step 4: Note the Outputs

After Terraform completes, save the following outputs:

```bash
# Get important values
terraform output alb_url                    # Your application URL
terraform output ecr_repository_url         # ECR repository URL
terraform output github_actions_role_arn    # IAM role for GitHub Actions
```

## Step 5: Initial Docker Image Push

Before GitHub Actions can deploy, we need to push an initial image to ECR.

**You can paste this entire block** (it will execute sequentially):

```bash
# Get ECR repository URL
ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url)
ECR_REGISTRY=$(echo $ECR_REPO | cut -d'/' -f1)

# Login to ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build Docker image (must be from project root to access frontend/)
cd ..  # Go back to project root if in terraform/
docker build -f backend/Dockerfile -t aws-chat-rag:latest .
# Note: Build context is project root (.), so Dockerfile can access both backend/ and frontend/

# Tag and push to ECR
docker tag aws-chat-rag:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

# Update ECS service to use this image
cd terraform
terraform apply -var="container_image=$ECR_REPO:latest"
```

**Note:** The last command will ask for `yes` confirmation.

## Step 6: Set up GitHub Repository

1. Create a new repository on GitHub (if not already created)

2. Add the remote and push code:

```bash
cd ..  # Back to project root
git remote add origin https://github.com/YOUR_USERNAME/aws-chat-rag.git
git push -u origin main
```

3. Add GitHub Secrets:

Go to your repository on GitHub:
- Settings → Secrets and variables → Actions → New repository secret

Add these secrets:

| Secret Name | Value |
|-------------|-------|
| `AWS_ROLE_ARN` | The `github_actions_role_arn` from Terraform output |
| `AWS_REGION` | `us-east-2` |

## Step 7: Enable pgvector Extension in RDS (Optional - Can Skip for Now)

**Note:** This step requires network access to RDS, which is in a private subnet. You can skip this for now and enable pgvector later when you have proper access (via EC2 instance, bastion host, or VPN).

**Why Skip Now:**
- RDS is in a private subnet (no direct internet access)
- Cannot connect from your local machine
- Application works fine without pgvector initially
- Can enable later when implementing RAG features

**To Enable Later (when you have network access):**

1. Connect from within the VPC (EC2 instance, bastion host, or VPN):
   ```bash
   # Get RDS endpoint
   cd terraform
   terraform output rds_endpoint
   
   # Connect using psql (install postgresql-client if needed)
   psql -h <rds-endpoint> -p 5432 -U postgres -d chatrag
   # Enter password when prompted (from terraform.tfvars)
   
   # Run these SQL commands:
   CREATE EXTENSION IF NOT EXISTS vector;
   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
   
   # Exit psql
   \q
   ```

**Alternative: Use AWS RDS Query Editor** (if available in your region):
- Go to AWS Console → RDS → Your Database → Query Editor
- Run the CREATE EXTENSION commands there

## Step 8: Verify Deployment

1. Wait for the ECS service to stabilize (2-3 minutes)

2. Get your application URL:

```bash
cd terraform
terraform output alb_url
```

3. Visit the URL in your browser - you should see the frontend!

4. Click the "Call /hello API" button to test

## Step 9: Test CI/CD Pipeline

Make a small change to test the deployment pipeline:

```bash
# Edit the hello message
echo '{"message": "Hello from CI/CD!"}' > test-change.txt

# Commit and push
git add .
git commit -m "Test: Update hello message"
git push origin main
```

Go to GitHub → Actions tab to watch the deployment.

## Architecture Overview

```
┌─────────────┐
│   GitHub    │
│   Actions   │
└──────┬──────┘
       │ OIDC Auth
       ▼
┌─────────────┐         ┌──────────────┐
│     ECR     │────────▶│     ECS      │
│  (Images)   │         │   Fargate    │
└─────────────┘         └──────┬───────┘
                               │
                               ▼
                        ┌──────────────┐
                        │     ALB      │
                        └──────┬───────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
             ┌─────────────┐       ┌─────────────┐
             │     RDS     │       │    Redis    │
             │ PostgreSQL  │       │ElastiCache  │
             │  Multi-AZ   │       └─────────────┘
             └─────────────┘
```

## Monitoring and Logs

### CloudWatch Logs

View application logs:

```bash
aws logs tail /ecs/aws-chat-rag --follow --region us-east-2
```

### CloudWatch Alarms

Check alarms in AWS Console:
- Go to CloudWatch → Alarms
- Monitor CPU, Memory, and Target Health
- **New:** `aws-chat-rag-alb-healthy-hosts-low` (alarms if 0 healthy targets)
- **New:** `aws-chat-rag-alb-5xx-errors` (alarms if > 3 errors in 1 minute)

These alarms help catch brief outages or 503 errors caused by health check failures.

### ECS Service

Check ECS service status:

```bash
aws ecs describe-services \
  --cluster aws-chat-rag-cluster \
  --services aws-chat-rag-service \
  --region us-east-2
```

## Troubleshooting

### Issue: ECS tasks keep restarting

1. Check CloudWatch logs for errors
2. Verify security group rules
3. Ensure RDS and Redis are accessible from ECS

### Issue: ALB returns 503

1. Check target group health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-2 --query 'TargetGroups[?contains(TargetGroupName, `aws-chat-rag`)].TargetGroupArn' --output text) \
  --region us-east-2
```

2. Verify `/health` endpoint is responding in the container

### Issue: Cannot connect to RDS

1. Check security group allows traffic from ECS security group
2. Verify database credentials in Secrets Manager
3. Check VPC networking configuration

## Cost Optimization

### Current estimated costs (us-east-2):

- **ECS Fargate** (256 CPU, 512 MB): ~$10/month
- **RDS db.t3.micro Multi-AZ**: ~$30/month
- **ElastiCache cache.t3.micro**: ~$15/month
- **NAT Gateways (2 AZs)**: ~$65/month
- **ALB**: ~$20/month
- **Data transfer**: Variable

**Total**: ~$140-150/month

### To reduce costs for development:

1. Disable Multi-AZ for RDS (set `db_multi_az = false`)
2. Use single NAT Gateway (modify `vpc.tf`)
3. Use smaller instance types
4. Stop ECS service when not in use

## Next Steps

Now that your infrastructure is running:

1. **Add HTTPS**: Configure ACM certificate and update ALB listener
2. **Custom Domain**: Set up Route53 for custom domain
3. **Implement RAG**: Add document processing and vector storage
4. **Add Authentication**: Implement user authentication system
5. **Work Queue**: Set up Celery/RQ for background jobs
6. **SSE Notifications**: Implement real-time notifications

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This will delete all AWS resources.

**Warning**: This is irreversible! Make sure to backup any data first.

