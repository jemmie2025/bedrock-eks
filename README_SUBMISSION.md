# Project Bedrock - Submission Summary

## Student Details

- Name: Jemimah Godswill
- Student ID: ALT/SOE/025/1483
- Region: us-east-1

## Project Scope Delivered

- Amazon EKS cluster: project-bedrock-cluster
- ALB ingress for external access (ALB-only path)
- In-cluster data services: MySQL, PostgreSQL, RabbitMQ, Redis, DynamoDB local
- Event-driven S3 -> Lambda processing (bedrock-asset-processor)
- CloudWatch observability for cluster, dataplane, app, and Lambda logs
- IAM + Kubernetes RBAC read-only access for bedrock-dev-view
- Terraform remote backend: S3 + DynamoDB locking

## Architecture Notes

- VPC with public/private subnets across 2 AZs
- EKS worker nodes in private subnets
- Ingress managed by AWS Load Balancer Controller
- RDS removed from final scope

## Deployment Commands (Executed Flow)

1) Backend setup

```bash
cd scripts
./setup-backend.sh
# or: .\setup-backend.ps1
```

2) Infrastructure provisioning

```bash
cd ../terraform
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
```

3) Configure cluster access

```bash
aws eks update-kubeconfig --name project-bedrock-cluster --region us-east-1
kubectl get nodes
```

4) Application deployment (Helm)

```bash
helm repo add retail-app https://aws.github.io/retail-store-sample-app
helm repo update
helm upgrade --install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/ui-values.yaml --create-namespace --wait --timeout 10m
helm upgrade --install catalog oci://public.ecr.aws/aws-containers/retail-store-sample-catalog-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/catalog-values.yaml --wait --timeout 10m
helm upgrade --install orders oci://public.ecr.aws/aws-containers/retail-store-sample-orders-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/orders-values.yaml --wait --timeout 10m
helm upgrade --install cart oci://public.ecr.aws/aws-containers/retail-store-sample-cart-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/cart-values.yaml --wait --timeout 10m
helm upgrade --install checkout oci://public.ecr.aws/aws-containers/retail-store-sample-checkout-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/checkout-value.yaml --wait --timeout 10m
kubectl apply -f k8s/ingress.yaml
```

5) Validation

```bash
helm list -n retail-app
kubectl get pods -n retail-app
kubectl get ingress -n retail-app
curl -I http://<ALB-DNS-NAME>
```

Expected result: HTTP/1.1 200 OK

## CI/CD (Step 12 Requirement)

Workflow: .github/workflows/terraform.yml

Push/Merge pipeline includes:

1. terraform init
2. terraform plan
3. terraform apply
4. helm upgrade --install retail ...

This satisfies the grader requirement for app deployment in CI/CD.

## Grading Artifact

```bash
cd terraform
terraform output -json > ../grading.json
```

Generated file: grading.json (contains required outputs for grading).

## Backend Verification

- S3 state bucket: bedrock-terraform-state-alt-soe-025-1483
- Versioning: Enabled
- Encryption: AES256
- DynamoDB lock table: bedrock-terraform-locks (ACTIVE)

## Reference Docs

- Full project documentation: README.md
- Detailed runbook: docs/deployment_guideline.md
- Pipeline guide: pipeline_guide.md
