# Bedrock EKS Infrastructure: Complete Deployment & Destruction Documentation

**Date Created:** February 22, 2026  
**Project:** Bedrock EKS (AWS Infrastructure as Code)  
**Student ID:** ALT/SOE/025/1483  
**Region:** us-east-1

---

## Table of Contents
1. [Phase 1: Initial Infrastructure Setup (Terraform)](#phase-1-initial-infrastructure-setup-terraform)
2. [Phase 2: GitHub Repository Configuration](#phase-2-github-repository-configuration)
3. [Phase 3: CI/CD Pipeline Implementation](#phase-3-cicd-pipeline-implementation)
4. [Phase 4: Application Deployment](#phase-4-application-deployment)
5. [Phase 5: Troubleshooting & Stabilization](#phase-5-troubleshooting--stabilization)
6. [Phase 6: Grading Compliance Adjustments](#phase-6-grading-compliance-adjustments)
7. [Phase 7: Resource Destruction](#phase-7-resource-destruction)

---

## Phase 1: Initial Infrastructure Setup (Terraform)

### Overview
Infrastructure as Code (IaC) solution using Terraform to provision AWS resources with remote state management.

### 1.1 Terraform Backend Configuration

**File:** `terraform/backend.tf`

```hcl
terraform {
  backend "s3" {
    bucket         = "bedrock-terraform-state-alt-soe-025-1483"
    key            = "bedrock/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bedrock-terraform-locks"
    encrypt        = true
  }
}
```

**Purpose:**
- Store Terraform state remotely in S3 for collaborative access
- Lock state using DynamoDB to prevent concurrent modifications
- Enable encryption for security

**Process:**
1. Create S3 bucket: `bedrock-terraform-state-alt-soe-025-1483`
2. Create DynamoDB table: `bedrock-terraform-locks` with `LockID` partition key
3. Enable versioning on S3 bucket for state recovery
4. Enable encryption on S3 bucket using AES256

### 1.2 AWS Provider Configuration

**File:** `terraform/providers.tf`

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "Bedrock"
      ManagedBy   = "Terraform"
      Environment = "production"
      StudentID   = "ALT/SOE/025/1483"
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
```

**Configuration Details:**
- AWS region: `us-east-1`
- Auto-tagging for resource tracking
- Kubernetes provider authenticated via EKS cluster endpoint
- Helm provider for Kubernetes package management

### 1.3 VPC Infrastructure Module

**File:** `modules/vpc/main.tf`

**Resources Created:**
- **VPC:** CIDR block `10.0.0.0/16`
- **Public Subnets (2):** 
  - `10.0.1.0/24` (us-east-1a)
  - `10.0.2.0/24` (us-east-1b)
- **Private Subnets (2):**
  - `10.0.11.0/24` (us-east-1a)
  - `10.0.12.0/24` (us-east-1b)
- **Internet Gateway:** Enables internet traffic for public subnets
- **Elastic IPs (2):** For NAT Gateway public IPs
- **NAT Gateways (2):** One per availability zone for private subnet egress
- **Route Tables:**
  - Public: Routes `0.0.0.0/0` to IGW
  - Private: Routes `0.0.0.0/0` to NAT Gateway
- **Network Tags:** Kubernetes-specific tags for ALB discovery

**Step-by-Step Process:**

1. **Create VPC**
   ```bash
   aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=project-bedrock-vpc},{Key=kubernetes.io/cluster/project-bedrock-cluster,Value=shared}]'
   ```

2. **Create Subnets**
   ```bash
   # Public Subnet 1 (AZ: us-east-1a)
   aws ec2 create-subnet --vpc-id vpc-095580d6a6c312713 --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
   
   # Private Subnet 1 (AZ: us-east-1a)
   aws ec2 create-subnet --vpc-id vpc-095580d6a6c312713 --cidr-block 10.0.11.0/24 --availability-zone us-east-1a
   ```

3. **Create Internet Gateway**
   ```bash
   aws ec2 create-internet-gateway
   aws ec2 attach-internet-gateway --internet-gateway-id igw-057acdc76aacc8ae2 --vpc-id vpc-095580d6a6c312713
   ```

4. **Create NAT Gateways**
   ```bash
   # Allocate Elastic IP
   aws ec2 allocate-address --domain vpc
   
   # Create NAT Gateway in public subnet
   aws ec2 create-nat-gateway --subnet-id subnet-0d7c1c43773db52d6 --allocation-id eipalloc-xxxxx
   ```

5. **Configure Route Tables**
   ```bash
   # Public Route Table
   aws ec2 create-route-table --vpc-id vpc-095580d6a6c312713
   aws ec2 create-route --route-table-id rtb-xxxxx --destination-cidr-block 0.0.0.0/0 --gateway-id igw-057acdc76aacc8ae2
   
   # Private Route Table
   aws ec2 create-route-table --vpc-id vpc-095580d6a6c312713
   aws ec2 create-route --route-table-id rtb-xxxxx --destination-cidr-block 0.0.0.0/0 --nat-gateway-id natgw-xxxxx
   ```

6. **Associate Subnets with Route Tables**
   ```bash
   aws ec2 associate-route-table --route-table-id rtb-public --subnet-id subnet-public1
   aws ec2 associate-route-table --route-table-id rtb-private --subnet-id subnet-private1
   ```

### 1.4 EKS Cluster Module

**File:** `modules/eks/main.tf`

**Resources Created:**
- **EKS Cluster:**
  - Name: `project-bedrock-cluster`
  - Version: `1.34`
  - Endpoint: Public (accessible)
  - Service CIDR: `172.20.0.0/16`
  - Control plane logging enabled for: api, audit, authenticator, controllerManager, scheduler

- **EKS Cluster Role:**
  - Trust policy: `eks.amazonaws.com`
  - Attached policies:
    - `AmazonEKSClusterPolicy`
    - `AmazonEKSVPCResourceController`

- **EKS Node Group:**
  - Name: `project-bedrock-cluster-node-group`
  - Instance type: `t3.large`
  - Desired size: 3 nodes
  - Min: 2, Max: 5
  - AMI: AL2023_x86_64_STANDARD
  - Disk size: 50 GB

- **Node Group Role:**
  - Trust policy: `ec2.amazonaws.com`
  - Attached policies:
    - `AmazonEKSWorkerNodePolicy`
    - `AmazonEKS_CNI_Policy`
    - `AmazonEC2ContainerRegistryReadOnly`
    - `CloudWatchAgentServerPolicy`

- **OIDC Provider:**
  - Enables IRSA (IAM Roles for Service Accounts)
  - Issuer URL: `https://oidc.eks.us-east-1.amazonaws.com/id/8EED69B2DD0F9473225C53B0BBB2AA5B`

- **EBS CSI Driver Add-on:**
  - Version: `v1.55.0-eksbuild.2`
  - Service account role with EBS permissions

**Step-by-Step Process:**

1. **Create IAM Role for Cluster**
   ```bash
   aws iam create-role --role-name project-bedrock-cluster-cluster-role \
     --assume-role-policy-document '{
       "Version": "2012-10-17",
       "Statement": [{
         "Effect": "Allow",
         "Principal": {"Service": "eks.amazonaws.com"},
         "Action": "sts:AssumeRole"
       }]
     }'
   ```

2. **Attach Cluster Policies**
   ```bash
   aws iam attach-role-policy --role-name project-bedrock-cluster-cluster-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
   
   aws iam attach-role-policy --role-name project-bedrock-cluster-cluster-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
   ```

3. **Create EKS Cluster**
   ```bash
   aws eks create-cluster \
     --name project-bedrock-cluster \
     --version 1.34 \
     --role-arn arn:aws:iam::816212136006:role/project-bedrock-cluster-cluster-role \
     --resources-vpc-config subnetIds=subnet-074144a84b81e3ff4,subnet-0fabe5e32f5c24d82,subnet-0d7c1c43773db52d6,subnet-007d44bacaaca72cf \
     --logging '{"clusterLogging":[{"enabled":true,"types":["api","audit","authenticator","controllerManager","scheduler"]}]}'
   ```

4. **Create Node Group IAM Role**
   ```bash
   aws iam create-role --role-name project-bedrock-cluster-node-group-role \
     --assume-role-policy-document '{
       "Version": "2012-10-17",
       "Statement": [{
         "Effect": "Allow",
         "Principal": {"Service": "ec2.amazonaws.com"},
         "Action": "sts:AssumeRole"
       }]
     }'
   ```

5. **Attach Node Group Policies**
   ```bash
   aws iam attach-role-policy --role-name project-bedrock-cluster-node-group-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
   
   aws iam attach-role-policy --role-name project-bedrock-cluster-node-group-role \
     --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
   ```

6. **Create Node Group**
   ```bash
   aws eks create-nodegroup \
     --cluster-name project-bedrock-cluster \
     --nodegroup-name project-bedrock-cluster-node-group \
     --scaling-config minSize=2,maxSize=5,desiredSize=3 \
     --subnets subnet-074144a84b81e3ff4 subnet-0fabe5e32f5c24d82 \
     --node-role arn:aws:iam::816212136006:role/project-bedrock-cluster-node-group-role \
     --instance-types t3.large \
     --disk-size 50
   ```

7. **Create OIDC Provider**
   ```bash
   # Extract OIDC provider URL from cluster
   OIDC_ID=$(aws eks describe-cluster --name project-bedrock-cluster \
     --query 'cluster.identity.oidc.issuer' --output text | cut -d'/' -f5)
   
   aws iam create-open-id-connect-provider \
     --url https://oidc.eks.us-east-1.amazonaws.com/id/${OIDC_ID} \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 06b25927c42a721631c1efd9431e648fa62e1e39
   ```

8. **Enable EBS CSI Driver Add-on**
   ```bash
   aws eks create-addon \
     --cluster-name project-bedrock-cluster \
     --addon-name aws-ebs-csi-driver \
     --service-account-role-arn arn:aws:iam::816212136006:role/ebs-csi-driver-role
   ```

### 1.5 IAM Module

**File:** `modules/iam/main.tf`

**Resources Created:**
- **Lambda Execution Role:** For asset processor Lambda function
- **ALB Controller Service Account Role:** For AWS ALB Ingress Controller
- **EBS CSI Driver Role:** For persistent volume management

**Policies:**
- Lambda: Full S3 access, CloudWatch logs
- ALB Controller: Ability to create/manage load balancers and tags
- EBS CSI: Full EC2 and EBS management permissions

### 1.6 RDS Module (Optional)

**File:** `modules/rds/main.tf`

- **Database:** MySQL 8.0 or PostgreSQL 15
- **Instance:** `db.t3.micro`
- **Storage:** 20 GB
- **Multi-AZ:** Enabled
- **Backup retention:** 7 days
- **Deletion protection:** Enabled
- **Secrets stored in:** AWS Secrets Manager and Kubernetes Secrets

### 1.7 Observability Module

**File:** `modules/observability/main.tf`

- **CloudWatch Log Groups:**
  - `/aws/eks/project-bedrock-cluster/cluster` - Control plane logs
  - `/aws/eks/project-bedrock-cluster/dataplane` - Node logs
  - `/aws/eks/project-bedrock-cluster/retail-store-sample-app` - Application logs
- **CloudWatch Metrics:** CPU, Memory, Pod count
- **Fluent Bit:** For log aggregation

### 1.8 K8s RBAC Module

**File:** `modules/k8s-rbac/main.tf`

**Resources Created:**
- **Namespace:** `retail-app` (or custom namespace)
- **Service Accounts:** For app components (cart, catalog, orders, checkout, ui)
- **RBAC Roles and Bindings:**
  ```yaml
  Kind: Role
  Metadata:
    Name: retail-app-role
    Namespace: retail-app
  Rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
  ```
- **aws-auth ConfigMap:** Maps IAM roles to Kubernetes users
  ```yaml
  mapRoles:
  - rolearn: arn:aws:iam::816212136006:role/project-bedrock-cluster-node-group-role
    username: system:node:{{EC2PrivateDNSName}}
    groups: ["system:bootstrappers", "system:nodes"]
  
  mapUsers:
  - userarn: arn:aws:iam::816212136006:user/ci-deployment-user
    username: ci-user
    groups: ["system:masters"]
  ```

---

## Phase 2: GitHub Repository Configuration

### 2.1 Repository Structure

**Initial Repository:** `godsw/bedrock-eks` (public)

```
bedrock-eks/
├── .github/
│   └── workflows/
│       └── terraform.yml          # Main CI/CD pipeline
├── terraform/
│   ├── main.tf                    # Root module configuration
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # Output values
│   ├── providers.tf               # Provider configuration
│   ├── backend.tf                 # Remote state backend
│   ├── terraform.tfvars           # Production variables
│   ├── cicd.tfvars                # CI/CD-specific variables
│   └── terraform.tfvars.example   # Template for variables
├── modules/
│   ├── vpc/                       # VPC infrastructure
│   ├── eks/                       # EKS cluster
│   ├── iam/                       # IAM roles and policies
│   ├── rds/                       # Database configuration
│   ├── alb-controller/            # ALB ingress controller
│   ├── k8s-rbac/                  # Kubernetes RBAC
│   ├── observability/             # CloudWatch and monitoring
│   └── serverless/                # Lambda functions
├── k8s/
│   ├── retail-app-values.yaml     # Helm values (default)
│   ├── retail-app-values-rds.yaml # Helm values (RDS mode)
│   ├── ingress.yaml               # ALB ingress specification
│   ├── alb-serviceaccount.yaml    # ALB controller service account
│   ├── db-secrets.yaml            # Database credentials
│   ├── ui-loadbalancer.yaml       # UI service loadbalancer
│   ├── ui-nodeport.yaml           # UI service nodeport
│   └── helm-overrides/            # Per-service helm values
│       ├── cart-values.yaml
│       ├── catalog-values.yaml
│       ├── checkout-values.yaml
│       ├── orders-values.yaml
│       └── ui-values.yaml
├── scripts/
│   ├── deploy-app.sh              # Bash deployment script
│   ├── deploy-app.ps1             # PowerShell deployment script
│   ├── setup-backend.sh           # Bash backend setup
│   ├── setup-backend.ps1          # PowerShell backend setup
│   ├── setup-alb-controller.ps1   # ALB controller setup
│   └── cleanup.sh                 # Cleanup script
├── lambda/
│   └── asset_processor.py         # Lambda function code
├── docs/
│   └── deployment_guideline.md    # Deployment guide
├── .gitignore                     # Git ignore configuration
├── README.md                      # Project documentation
└── pipeline_guide.md              # CI/CD pipeline guide
```

### 2.2 GitHub Secrets Configuration

**Secrets Required for CI/CD:**

1. **AWS Credentials**
   ```
   AWS_ACCESS_KEY_ID=AKIAXXXXXXXXXXXXXXXX
   AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

2. **GitHub Token** (for API access)
   ```
   GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```

3. **Terraform State Bucket**
   - S3 bucket name: `bedrock-terraform-state-alt-soe-025-1483`
   - DynamoDB table: `bedrock-terraform-locks`

**GitHub Secrets Setup Process:**

```bash
# Using GitHub CLI
gh secret set AWS_ACCESS_KEY_ID --body "AKIAXXXXXXXXXXXXXXXX" -R godsw/bedrock-eks
gh secret set AWS_SECRET_ACCESS_KEY --body "secret_key_here" -R godsw/bedrock-eks
gh secret set GH_TOKEN --body "token_here" -R godsw/bedrock-eks
```

### 2.3 Repository Branches & Protection Rules

**Main branches:**
- `main` - Production branch (auto-deploy on push)
- `develop` - Development branch (manual approval for deploy)

**Branch Protection Rules on `main`:**
- Require pull request reviews before merging
- Require status checks to pass before merging
- Require branches to be up to date before merging
- Include administrators in restrictions

---

## Phase 3: CI/CD Pipeline Implementation

### 3.1 GitHub Actions Workflow

**File:** `.github/workflows/terraform.yml`

**Workflow Structure:**

```yaml
name: Terraform Plan/Apply & Deploy Retail App
on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'k8s/**'
      - '.github/workflows/terraform.yml'
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'k8s/**'
  workflow_dispatch:

env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.14.5

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    permissions:
      contents: read
      pull-requests: write
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Terraform Init
        run: |
          cd terraform
          terraform init -input=false
      
      - name: Terraform Validate
        run: |
          cd terraform
          terraform validate
      
      - name: Terraform Plan (PR)
        run: |
          cd terraform
          terraform plan -input=false -out=tfplan
      
      - name: Post plan to PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('./terraform/tfplan', 'utf-8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '```\n' + plan.slice(0, 65000) + '\n```'
            });

  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    needs: []
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Terraform Init
        run: |
          cd terraform
          terraform init -input=false -lock-timeout=5m
      
      - name: Terraform Plan
        run: |
          cd terraform
          terraform plan -input=false -out=tfplan -lock-timeout=5m
      
      - name: Terraform Apply
        run: |
          cd terraform
          terraform apply -input=false -lock-timeout=5m tfplan
      
      - name: Get Terraform Outputs
        id: tf_outputs
        run: |
          cd terraform
          echo "::set-output name=cluster_name::$(terraform output -raw cluster_name)"
          echo "::set-output name=cluster_endpoint::$(terraform output -raw cluster_endpoint)"

  deploy:
    name: Deploy retail-store-sample-app
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    needs: [apply]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name project-bedrock-cluster
      
      - name: Create namespace and RBAC
        run: |
          kubectl create namespace retail-app --dry-run=client -o yaml | kubectl apply -f -
          kubectl apply -f k8s/alb-serviceaccount.yaml
      
      - name: Deploy ALB Ingress Controller
        run: |
          helm repo add eks https://aws.github.io/eks-charts
          helm repo update
          helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
            -n kube-system \
            --set clusterName=project-bedrock-cluster \
            --set serviceAccount.create=true \
            --set serviceAccount.name=aws-load-balancer-controller
      
      - name: Deploy Retail App (Local Charts)
        run: |
          git clone https://github.com/aws-containers/retail-store-sample-app.git /tmp/retail-app
          helm upgrade --install retail-store-sample-app /tmp/retail-app/deploy/kubernetes \
            -n retail-app \
            -f k8s/retail-app-values.yaml \
            -f k8s/helm-overrides/cart-values.yaml \
            -f k8s/helm-overrides/catalog-values.yaml \
            -f k8s/helm-overrides/checkout-values.yaml \
            -f k8s/helm-overrides/orders-values.yaml \
            -f k8s/helm-overrides/ui-values.yaml \
            --wait \
            --timeout 10m
      
      - name: Deploy Ingress
        run: |
          kubectl apply -f k8s/ingress.yaml
      
      - name: Verify Deployment
        run: |
          kubectl -n retail-app rollout status deployment/ui --timeout=5m
          kubectl -n retail-app get pods
          kubectl -n retail-app get svc
```

### 3.2 Workflow Trigger Points

**Trigger Scenario 1: Pull Request**
- Event: `push` to any branch with `pull_request` to `main`
- Action: Run `plan` job only
- Output: Terraform plan posted to PR comment

**Trigger Scenario 2: Push to Main**
- Event: `push` directly to `main` branch
- Action: Run `apply` and `deploy` jobs
- Output: Infrastructure created/updated, app deployed

**Trigger Scenario 3: Manual Dispatch**
- Event: `workflow_dispatch` (Run workflow button in GitHub Actions UI)
- Action: Execute full pipeline

### 3.3 CI/CD Variable Configuration

**File:** `terraform/cicd.tfvars`

```hcl
# CI/CD specific overrides
aws_region                           = "us-east-1"
cluster_name                         = "project-bedrock-cluster"
node_group_desired_size              = 3
node_group_min_size                  = 2
node_group_max_size                  = 5
enable_k8s_rbac                      = true
enable_alb_ingress                   = true
enable_observability                 = true
enable_rds                           = false
app_namespace                        = "retail-app"
container_registry                   = "public.ecr.aws"
```

**Gitignore Exception:**
```
# .gitignore with exception:
# Ignore Terraform files except for CI/CD variables
terraform.tfstate*
*.tfvars
!terraform/cicd.tfvars         # Keep this file for CI/CD
!terraform/terraform.tfvars    # Keep this file for production
```

---

## Phase 4: Application Deployment

### 4.1 Helm Chart Deployment Strategy

**Initial Strategy (OCI Registry):**

```bash
# Public ECR registry for AWS retail sample app
helm search repo public.ecr.aws/aws-containers/retail-store-sample-app
helm pull oci://public.ecr.aws/aws-containers/retail-store-sample-app --version 1.0.0
```

**Issue Encountered:** OCI chart pulls sometimes timeout in CI environment.

**Fallback Strategy (Local Clone):**

```bash
# Clone the retail app repository locally
git clone https://github.com/aws-containers/retail-store-sample-app.git /tmp/retail-app

# Deploy using local charts
helm upgrade --install retail-store-sample-app /tmp/retail-app/deploy/kubernetes \
  -n retail-app \
  -f k8s/retail-app-values.yaml \
  --wait \
  --timeout 10m
```

### 4.2 Helm Values Configuration

**File:** `k8s/retail-app-values.yaml`

```yaml
# Global configuration
global:
  region: us-east-1
  namespace: retail-app

# MySQL Configuration
mysql:
  enabled: true
  auth:
    rootPassword: "changeMe123!"
    database: "retail"
  primary:
    persistence:
      enabled: false  # Disabled per grading requirements
    resources:
      limits:
        cpu: 500m
        memory: 512Mi

# PostgreSQL Configuration (if enabled)
postgresql:
  enabled: false
  auth:
    postgresPassword: "changeMe123!"
  primary:
    persistence:
      enabled: false
    resources:
      limits:
        cpu: 500m
        memory: 512Mi

# Redis Configuration
redis:
  enabled: true
  master:
    persistence:
      enabled: false  # Disabled per grading requirements
    resources:
      limits:
        cpu: 100m
        memory: 128Mi

# RabbitMQ Configuration
rabbitmq:
  enabled: true
  auth:
    username: "guest"
    password: "guest"
  persistence:
    enabled: false  # Disabled per grading requirements
  resources:
    limits:
      cpu: 100m
      memory: 256Mi

# Service configurations
services:
  ui:
    type: LoadBalancer
    port: 80
    replicas: 2
  cart:
    replicas: 2
  catalog:
    replicas: 2
  orders:
    replicas: 2
  checkout:
    replicas: 2

# Image configuration
image:
  registry: public.ecr.aws
  repository: aws-containers
```

### 4.3 Helm Overrides per Service

**File:** `k8s/helm-overrides/catalog-values.yaml`

```yaml
catalog:
  enabled: true
  replicas: 2
  persistence:
    enabled: false
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  nodeSelector: {}
  tolerations: []
  affinity: {}
```

### 4.4 ALB Ingress Configuration

**File:** `k8s/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: retail-app-ingress
  namespace: retail-app
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ui
            port:
              number: 80
      - path: /api/cart
        pathType: Prefix
        backend:
          service:
            name: cart
            port:
              number: 8080
      - path: /api/catalog
        pathType: Prefix
        backend:
          service:
            name: catalog
            port:
              number: 8080
      - path: /api/orders
        pathType: Prefix
        backend:
          service:
            name: orders
            port:
              number: 8080
      - path: /api/checkout
        pathType: Prefix
        backend:
          service:
            name: checkout
            port:
              number: 8080
```

### 4.5 Database and Secrets Management

**File:** `k8s/db-secrets.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: retail-app
type: Opaque
stringData:
  mysql_host: mysql.retail-app.svc.cluster.local
  mysql_user: root
  mysql_password: "changeMe123!"
  mysql_database: retail
  redis_host: redis.retail-app.svc.cluster.local
  redis_port: "6379"
  rabbitmq_host: rabbitmq.retail-app.svc.cluster.local
  rabbitmq_user: "guest"
  rabbitmq_password: "guest"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: retail-app
data:
  LOG_LEVEL: "INFO"
  ENABLE_XRAY: "false"
  ENVIRONMENT: "production"
```

### 4.6 Deployment Validation Steps

**Step 1: Verify Namespace**
```bash
kubectl get namespace retail-app
```

**Step 2: Verify All Pods Running**
```bash
kubectl -n retail-app get pods --watch
```

**Step 3: Verify Services**
```bash
kubectl -n retail-app get svc
# Output:
# NAME              TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)
# ui                LoadBalancer   172.20.x.x      xxx.xxx.xx.x  80:xxxxx/TCP
# cart              ClusterIP      172.20.x.x      <none>        8080/TCP
# catalog           ClusterIP      172.20.x.x      <none>        8080/TCP
# orders            ClusterIP      172.20.x.x      <none>        8080/TCP
# checkout          ClusterIP      172.20.x.x      <none>        8080/TCP
```

**Step 4: Verify Ingress**
```bash
kubectl -n retail-app get ingress
# Output shows ALB ingress with hostname
```

**Step 5: Test Application**
```bash
# Get ALB endpoint
ALB_ENDPOINT=$(kubectl -n retail-app get ingress retail-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test UI endpoint
curl -v http://${ALB_ENDPOINT}

# Test API endpoints
curl http://${ALB_ENDPOINT}/api/catalog/products
curl http://${ALB_ENDPOINT}/api/cart/items
curl http://${ALB_ENDPOINT}/api/orders/list
```

**Step 6: Monitor Logs**
```bash
# Control plane logs
aws logs tail /aws/eks/project-bedrock-cluster/cluster --follow

# Application logs
kubectl -n retail-app logs -f deployment/ui
kubectl -n retail-app logs -f deployment/catalog
```

---

## Phase 5: Troubleshooting & Stabilization

### 5.1 GitHub Actions Issues Resolution

**Issue 1: Workflow Skipped/Manual Trigger**

**Symptom:** Workflow not automatically running on push to main

**Root Cause:** Job conditions not properly configured for non-PR events

**Solution:**
```yaml
# Added proper job conditions:
apply:
  if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
  
deploy:
  if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
```

**Issue 2: Terraform Apply Fails - No tfplan Generated**

**Symptom:** 
```
Error: Insufficient or invalid data:
Failed to load tfplan
```

**Root Cause:** Plan job produces tfplan, but apply job wasn't reading it

**Solution:**
```yaml
# Explicitly generate tfplan in apply job:
- name: Terraform Plan
  run: |
    cd terraform
    terraform plan -input=false -out=tfplan -lock-timeout=5m

- name: Terraform Apply
  run: |
    cd terraform
    terraform apply -input=false -lock-timeout=5m tfplan
```

**Issue 3: Missing terraform/cicd.tfvars**

**Symptom:**
```
Error: Missing required variable "enable_k8s_rbac"
```

**Root Cause:** CI/CD specific variables not provided

**Solution:**
1. Create `terraform/cicd.tfvars`
2. Add to variables.tf as optional vars with defaults
3. Update `.gitignore` exception:
   ```
   !terraform/cicd.tfvars
   ```

**Issue 4: State Lock Timeout**

**Symptom:**
```
Failed to acquire lock: operation timed out after 10 minutes
```

**Root Cause:** Another operation holding lock (previous failed apply)

**Solution:**
```yaml
- name: Terraform Init
  run: |
    cd terraform
    terraform init -input=false -lock-timeout=5m

- name: Force Unlock (if needed)
  if: failure()
  run: |
    cd terraform
    terraform force-unlock <lock-id>
```

### 5.2 Kubernetes Cluster Access Issues

**Issue 5: aws-auth ConfigMap Misconfigured**

**Symptom:**
```
error: You must be logged in to the server (Unauthorized)
```

**Root Cause:** IAM user/role not mapped in aws-auth ConfigMap

**Solution:**
```bash
# Get current aws-auth
kubectl get configmap w-auth -n kube-system -o yaml > aws-auth.yaml

# Verify structure:
# mapRoles:
# - rolearn: arn:aws:iam::ACCOUNT:role/NodeGroupRole
#   username: system:node:{{EC2PrivateDNSName}}
#   groups: ["system:bootstrappers", "system:nodes"]

# mapUsers:
# - userarn: arn:aws:iam::ACCOUNT:user/ci-user
#   username: ci-user
#   groups: ["system:masters"]

# Apply corrected config
kubectl apply -f aws-auth.yaml
```

**Issue 6: Node Group Status DEGRADED**

**Symptom:**
```
Status: DEGRADED
Message: EC2 instances not ready
```

**Root Cause:** Nodes taking time to bootstrap or security group rules blocking communication

**Solution:**
```bash
# Check node status
kubectl get nodes -o wide

# Check node logs
aws ec2 describe-instances --filters "Name=eks:cluster-name,Values=project-bedrock-cluster" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'

# Check security group rules
aws ec2 describe-security-groups --filters "Name=group-name,Values=eks-cluster-sg-*" \
  --query 'SecurityGroups[*].IpPermissions'

# If needed, scale node group down and back up
aws eks update-nodegroup-config \
  --cluster-name project-bedrock-cluster \
  --nodegroup-name project-bedrock-cluster-node-group \
  --scaling-config minSize=1,maxSize=5,desiredSize=2

sleep 300

aws eks update-nodegroup-config \
  --cluster-name project-bedrock-cluster \
  --nodegroup-name project-bedrock-cluster-node-group \
  --scaling-config minSize=2,maxSize=5,desiredSize=3
```

### 5.3 Application Deployment Issues

**Issue 7: Helm Chart Installation Timeout**

**Symptom:**
```
Error: INTERNAL ERROR: failed to fill template
Error: timeout waiting for condition
```

**Root Cause:** Chart pulling from registry timeout or pod image pull timeout

**Solution:**
```bash
# Option 1: Use local charts
git clone https://github.com/aws-containers/retail-store-sample-app.git /tmp/retail-app
helm upgrade --install retail-store-sample-app /tmp/retail-app/deploy/kubernetes \
  -n retail-app \
  -f k8s/retail-app-values.yaml \
  --wait \
  --timeout 15m  # Increased timeout

# Option 2: Pre-pull images
kubectl set image deployment/cart \
  cart=public.ecr.aws/aws-containers/retail-store-sample-app:latest \
  -n retail-app
```

**Issue 8: Pod CrashLoopBackOff - Application Not Starting**

**Symptom:**
```
NAME    READY   STATUS             RESTARTS
catalog 0/1     CrashLoopBackOff   5
```

**Diagnosis:**
```bash
kubectl -n retail-app logs catalog-xxxxx --previous
kubectl -n retail-app describe pod catalog-xxxxx
kubectl -n retail-app get events --sort-by='.lastTimestamp'
```

**Common Causes & Solutions:**

a) **Missing database connection:**
```bash
# Verify database is running
kubectl -n retail-app get pod -l app=mysql

# Check database credentials in secret
kubectl -n retail-app get secret db-credentials -o yaml

# Update database host in environment
kubectl -n retail-app set env deployment/catalog \
  DB_HOST=mysql.retail-app.svc.cluster.local
```

b) **Image pull error:**
```bash
# Check image availability
aws ecr describe-images --repository-name aws-containers/retail-store-sample-app

# Update image pull policy
kubectl -n retail-app patch deployment catalog \
  -p '{"spec":{"template":{"spec":{"imagePullPolicy":"IfNotPresent"}}}}'
```

c) **Resource constraints:**
```bash
# Check node resources
kubectl top nodes

# Update resource requests
kubectl -n retail-app set resources deployment/catalog \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=500m,memory=512Mi
```

### 5.4 Persistence Configuration Fix

**Issue 9: Persistence Flag Set to True (Grading Blocker)**

**Symptom:** Instructor feedback: "in-app persistence used"

**Root Cause:** Helm values had `persistence.enabled: true` for databases

**Solution:**
Set all persistence flags to `false`:

**File Changes:**
1. `k8s/retail-app-values.yaml`
2. `k8s/helm-overrides/catalog-values.yaml`
3. `k8s/helm-overrides/orders-values.yaml`

```yaml
# Before:
mysql:
  primary:
    persistence:
      enabled: true  # ❌ Wrong

# After:
mysql:
  primary:
    persistence:
      enabled: false  # ✅ Correct

redis:
  master:
    persistence:
      enabled: false  # ✅ Correct

rabbitmq:
  persistence:
    enabled: false  # ✅ Correct
```

---

## Phase 6: Grading Compliance Adjustments

### 6.1 Persistence Flags

**All persistence disabled across all Helm values:**

```bash
# Verify no persistence enabled
grep -r "enabled: true" k8s/helm-overrides/ k8s/retail-app-values.yaml | \
  grep -i persistence
# Should return: (empty)
```

### 6.2 CI/CD Variable Optimization

**File:** `terraform/cicd.tfvars`

```hcl
# Optimized for grading stability
enable_k8s_rbac          = true   # Ensure RBAC exists
enable_alb_ingress       = true   # ALB controller needed
enable_observability     = false  # Reduce infrastructure
enable_rds               = false  # Use in-cluster MySQL
enable_persistence       = false  # No persistent storage
```

### 6.3 Successful Workflow Run Target

**Target Metrics:**
1. ✅ Plan job completes successfully
2. ✅ Apply job completes successfully
3. ✅ All Terraform resources created
4. ✅ Deploy job completes successfully
5. ✅ All app pods running
6. ✅ ALB ingress operational
7. ✅ Application responds with HTTP 200

---

## Phase 7: Resource Destruction

### 7.1 Destruction Strategy

**Objective:** Complete teardown of all AWS resources while preserving code

### 7.2 Step-by-Step Destruction Process

**Step 1: Identify Resources to Destroy**

```bash
cd terraform

# View all resources
terraform state list

# View specific resource details
terraform state show module.eks.aws_eks_cluster.main

# Estimate destruction impact
terraform plan -destroy
```

**Step 2: Remove Out-of-Band ALB Resources**

**Issue:** ALB created by ingress controller not managed by Terraform

```bash
# Find lingering load balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[?VpcId==`vpc-095580d6a6c312713`].[LoadBalancerArn,LoadBalancerName,State.Code]' \
  --output table

# Delete identified load balancers
aws elbv2 delete-load-balancer \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:816212136006:loadbalancer/app/k8s-retailap-retailap-3c6aa53d7a/5523106d73b9f297

# Wait for deletion
aws elbv2 wait load-balancers-deleted \
  --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:816212136006:loadbalancer/app/k8s-retailap-retailap-3c6aa53d7a/5523106d73b9f297
```

**Step 3: Check for Kubernetes Namespace Deletion Blockers**

```bash
# Check k8s resources
kubectl get all -n retail-app

# If namespace stuck in Terminating state
kubectl delete deployment --all -n retail-app
kubectl delete service --all -n retail-app
kubectl delete ingress --all -n retail-app

# Then remove namespace from state (if destroy hangs)
terraform state rm 'module.k8s_rbac[0].kubernetes_namespace.retail_app'
```

**Step 4: Execute Terraform Destroy**

```bash
# Execute full destroy with auto-approval
terraform destroy -auto-approve -input=false

# If hanging on VPC deletion, note remaining dependencies
```

**Destruction Sequence (Automatic):**

1. **EBS CSI Driver Add-on** (5 min)
   ```
   aws_eks_addon.ebs_csi: Destroying...
   aws_eks_addon.ebs_csi: Destruction complete
   ```

2. **EKS Node Group** (10-15 min)
   ```
   aws_eks_node_group.main: Destroying...
   aws_eks_node_group.main: Destruction complete
   ```

3. **Auto Scaling Group & EC2 Instances** (automatic with node group)

4. **EKS Cluster** (3-5 min)
   ```
   aws_eks_cluster.main: Destroying...
   aws_eks_cluster.main: Still destroying... [00m30s elapsed]
   aws_eks_cluster.main: Destruction complete after 3m45s
   ```

5. **Security Groups** (1-2 min)
   ```
   aws_security_group.cluster: Destroying...
   aws_security_group.node_group: Destroying...
   ```

6. **IAM Roles & Policies** (immediate)
   ```
   aws_iam_role_policy_attachment.*: Destroying...
   aws_iam_role.*: Destroying...
   ```

7. **VPC Resources**
   - Subnets (1-2 min)
   - Internet Gateway (immediate)
   - NAT Gateways (2-3 min)
   - Route Tables (immediate)
   - VPC itself (5-10 min)

**Step 5: Handle Destruction Blockers**

**If VPC deletion times out:**

```bash
# Check remaining ENIs
aws ec2 describe-network-interfaces \
  --filters Name=vpc-id,Values=vpc-095580d6a6c312713 \
  --output table

# Check for lingering NAT gateways
aws ec2 describe-nat-gateways \
  --filter Name=vpc-id,Values=vpc-095580d6a6c312713

# Check for lingering internet gateways
aws ec2 describe-internet-gateways \
  --filters Name=attachment.vpc-id,Values=vpc-095580d6a6c312713

# Force remove stuck resources from Terraform state
terraform state rm -lock=false 'module.vpc.aws_vpc.main'

# Remove remaining state artifacts
terraform state rm -lock=false \
  'module.eks.data.aws_partition.current' \
  'module.eks.aws_iam_role.cluster' \
  'module.vpc.aws_subnet.private[0]' \
  'module.vpc.aws_subnet.private[1]'
```

### 7.3 Post-Destruction Verification

**Verify all resources deleted:**

```bash
# Check Terraform state is empty
terraform state list
# Should output: (empty)

# Verify AWS resources deleted
aws eks describe-cluster --name project-bedrock-cluster 2>&1
# Error: ResourceNotFoundException (expected)

aws ec2 describe-vpcs --vpc-ids vpc-095580d6a6c312713 2>&1
# Error: InvalidVpcID.NotFound (expected)

# Verify Lambda function deleted
aws lambda get-function --function-name bedrock-asset-processor 2>&1
# Error: ResourceNotFoundException (expected)

# Verify RDS deleted (if enabled)
aws rds describe-db-instances --db-instance-identifier bedrock-db 2>&1
# Error: DBInstanceNotFoundFault (expected)
```

### 7.4 Cost Impact of Full Destruction

**Deleted Billing Streams:**
- EKS cluster: ~$0.10/hour
- EC2 t3.large (3 nodes): ~$0.10/hour × 3 = $0.30/hour
- NAT Gateways (2): ~$0.045/hour × 2 = $0.09/hour
- Data transfer out: $0 (will stop)
- Load Balancer: ~$0.0225/hour
- **Total stopped:** ~$0.51/hour × 730 hours/month = ~$372/month

### 7.5 Cleanup Actions Post-Destruction

**Preserve for Future Redeployment:**

```bash
# Code remains untouched
git status
# Clean working directory

# State file empty but bucket persists (for future use)
aws s3 ls bedrock-terraform-state-alt-soe-025-1483/

# DynamoDB lock table persists (for future use)
aws dynamodb scan --table-name bedrock-terraform-locks
```

**Optional: Full Account Cleanup**

```bash
# Delete S3 bucket (requires empty state)
aws s3 rm s3://bedrock-terraform-state-alt-soe-025-1483 --recursive
aws s3api delete-bucket --bucket bedrock-terraform-state-alt-soe-025-1483

# Delete DynamoDB table
aws dynamodb delete-table --table-name bedrock-terraform-locks

# Delete CloudWatch log groups
aws logs delete-log-group --log-group-name /aws/eks/project-bedrock-cluster/cluster
aws logs delete-log-group --log-group-name /aws/eks/project-bedrock-cluster/dataplane
aws logs delete-log-group --log-group-name /aws/eks/project-bedrock-cluster/retail-store-sample-app
```

---

## Summary: Complete Lifecycle

### Deployment Timeline
| Phase | Duration | Status |
|-------|----------|--------|
| VPC & Network Setup | 5 min | ✅ Complete |
| EKS Cluster Creation | 15 min | ✅ Complete |
| Node Group Launch | 10 min | ✅ Complete |
| RBAC & Add-ons Setup | 5 min | ✅ Complete |
| Application Helm Deployment | 5 min | ✅ Complete |
| ALB Ingress Configuration | 2 min | ✅ Complete |
| **Total Deployment** | **~42 min** | ✅ Complete |

### Destruction Timeline
| Phase | Duration | Status |
|--------|----------|--------|
| Delete EBS CSI Add-on | 5 min | ✅ Complete |
| Delete Node Group & Nodes | 15 min | ✅ Complete |
| Delete EKS Cluster | 5 min | ✅ Complete |
| Delete Security Groups & IAM | 2 min | ✅ Complete |
| Delete VPC Resources | 10 min | ✅ Complete (with manual cleanup) |
| **Total Destruction** | **~37 min** | ✅ Complete |

### Key Technologies Used
- **Infrastructure:** AWS EKS, VPC, IAM, CloudWatch, Lambda
- **Container Orchestration:** Kubernetes 1.34
- **Package Management:** Helm 3.x
- **Infrastructure as Code:** Terraform 1.14+
- **CI/CD:** GitHub Actions
- **Application:** AWS Retail Store Sample App (Java microservices)
- **Databases:** MySQL, Redis, RabbitMQ (in-cluster)
- **Ingress Controller:** AWS ALB Ingress Controller

### Cost Summary
- **Monthly estimate (while running):** ~$372/month
- **Total cost for deployment + operation + destruction:** ~$2-3 (minimal usage)

---

## Lessons Learned & Best Practices

### What Worked Well
1. ✅ Terraform modules for code reusability
2. ✅ Remote state with locking for concurrency safety
3. ✅ GitHub Actions for automated deployments
4. ✅ Helm for declarative app deployment
5. ✅ AWS ALB Ingress Controller for automatic LB provisioning

### Challenges & Solutions
1. ❌ Helm OCI chart timeouts → Use local chart clones
2. ❌ Kubernetes namespace deletion hangs → Remove from state
3. ❌ State lock contention → Add `-lock-timeout` flags
4. ❌ VPC deletion blockers → Manually delete out-of-band resources
5. ❌ Persistence flag in grading → Disabled all PVCs

### Recommendations for Production
1. Enable RDS for production databases (not in-cluster)
2. Use managed RBAC via AWS IAM Roles for Service Accounts (IRSA)
3. Implement Kubernetes network policies
4. Set up pod resource limits and requests
5. Enable EBS encryption for volumes
6. Use private subnets for all workloads
7. Implement VPC Flow Logs for traffic monitoring
8. Set up budget alerts in AWS Cost Explorer
9. Enable AWS Config for governance
10. Implement secrets management (AWS Secrets Manager integration)

