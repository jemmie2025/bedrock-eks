# CI/CD Pipeline Guide

This guide explains how to trigger and monitor the GitHub Actions CI/CD pipeline for Project Bedrock infrastructure and application deployment.

## Project Details

- **Student Name**: Jemimah Godswill
- **Student ID**: ALT/SOE/025/1483
- **Repository**: https://github.com/jemmie2025/bedrock-eks.git
- **Workflow File**: `.github/workflows/terraform.yml`

## Pipeline Overview

The pipeline automates Terraform infrastructure lifecycle and application deployment to EKS.

### CI/CD Flow Diagram

```mermaid
flowchart LR
  PR[Pull Request to main] --> PR1[terraform init]
  PR1 --> PR2[terraform validate]
  PR2 --> PR3[terraform plan]
  PR3 --> PR4[Plan review only - no apply]

  PUSH[Push/Merge to main] --> P1[1) terraform init]
  P1 --> P2[2) terraform plan]
  P2 --> P3[3) terraform apply]
  P3 --> P4[terraform output -json > grading.json]
  P4 --> P5[4) helm upgrade --install retail ...]
  P5 --> P6[Capture ALB URL in workflow summary]

  MANUAL[workflow_dispatch] --> PUSH
```

### Deployment-critical sequence (implemented)

On push/merge to `main`, the pipeline executes:

1. `terraform init`
2. `terraform plan`
3. `terraform apply`
4. `helm upgrade --install retail ...`

This satisfies the Step 12 grading requirement that CI/CD must include app deployment.

## Automatic Triggers

The workflow runs automatically for:

### 1) Push to `main`

Any push to `main` touching deployment files triggers the workflow:

```bash
git add .
git commit -m "Update infrastructure/application deployment"
git push origin main
```

**Path filters in workflow**:

- `terraform/**`
- `k8s/**`
- `.github/workflows/terraform.yml`

### 2) Pull Request to `main`

When a PR targets `main`, plan-only validation runs:

```bash
git checkout -b feature/my-change
git add .
git commit -m "Infra change for review"
git push origin feature/my-change
```

Then open a PR in GitHub.

PR behavior:

- `terraform init`
- `terraform validate`
- `terraform plan`

No apply is executed on PR.

## Manual Trigger

`workflow_dispatch` is enabled for this workflow.

### Run from GitHub UI

1. Open repository Actions page:  
   `https://github.com/jemmie2025/bedrock-eks/actions`
2. Select **Terraform CI/CD**
3. Click **Run workflow**
4. Choose branch (usually `main`) and run

### Run from GitHub CLI

```bash
gh workflow run "Terraform CI/CD" --ref main
```

Note: the current workflow does not use custom `action=plan/apply` inputs.

## Pipeline Jobs

The workflow contains 3 jobs:

### 1) Terraform Plan (PR only)

- Checks out code
- Sets up Terraform
- Configures AWS credentials
- Runs `terraform init`, `terraform validate`, `terraform plan`

### 2) Terraform Apply (Push to `main`)

- Checks out code
- Sets up Terraform
- Configures AWS credentials
- Runs `terraform init`, `terraform plan`, `terraform apply`
- Generates `grading.json` using Terraform outputs
- Uploads `grading.json` as workflow artifact

### 3) Deploy Retail App (Push to `main`)

- Sets up kubectl and Helm
- Configures kubeconfig for `project-bedrock-cluster`
- Deploys app with Helm:
  - `helm upgrade --install retail retail-app/retail-app ...`
- Captures ALB URL in workflow summary

## Monitoring Pipeline Execution

### View logs

1. Open: `https://github.com/jemmie2025/bedrock-eks/actions`
2. Click a workflow run
3. Open each job and step for detailed logs

### Status indicators

- ✅ Success
- 🟡 In progress
- ❌ Failed
- ⚪ Skipped

## Expected Behavior

### On Pull Request

- Terraform validation and plan complete
- No infrastructure changes applied

### On Push to `main`

- Terraform apply completes
- `grading.json` artifact generated
- Retail app is deployed with Helm
- ALB application URL appears in workflow summary

## Troubleshooting

### Pipeline fails

Common causes:

- Missing/invalid AWS secrets
- Terraform state lock contention
- IAM permission constraints
- EKS access/bootstrap problems

Resolution path:

1. Open failed run logs
2. Identify failing step
3. Correct root cause and re-run workflow

### ALB URL not ready immediately

ALB provisioning can take a few minutes. Re-check:

```bash
kubectl get ingress -n retail-app
kubectl describe ingress retail-app-ingress -n retail-app
```

### Unexpected Terraform plan changes

```bash
cd terraform
terraform plan
```

Review for drift (manual out-of-band changes in AWS).

## Required GitHub Secrets

Set repository secrets at:

`Settings -> Secrets and variables -> Actions`

Required:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Best Practices

1. Use PRs for all infrastructure changes.
2. Review Terraform plan before merge.
3. Keep workflow file only in `.github/workflows/`.
4. Keep credentials out of code and use GitHub Secrets only.
5. Re-run failed jobs only after root-cause correction.

## Related Documents

- `README.md` - Full architecture and operations guide
- `README_SUBMISSION.md` - One-page submission summary
- `docs/deployment_guideline.md` - End-to-end deployment runbook

---

**Last Updated**: February 2026  
**Repository**: https://github.com/jemmie2025/bedrock-eks.git
