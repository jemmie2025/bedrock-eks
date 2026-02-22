# Deployment Guideline (Step-by-Step)

This guide documents the exact deployment flow for the current project state.

## 0) Final Scope (What is in/out)

- Ingress model: **ALB only**
- Databases: **in-cluster** (MySQL, PostgreSQL, RabbitMQ, Redis, DynamoDB local)
- RDS: **removed from architecture**
- NodePort/NLB UI exposure: **removed**
- CI/CD includes Terraform + Helm application deployment

## 1) Prerequisites

Ensure the following are installed and configured:

- AWS CLI (authenticated to account `816212136006`)
- Terraform `>= 1.5`
- kubectl
- Helm

Verify identity:

```bash
aws sts get-caller-identity
```

## 2) Repository and Naming Standards Check

Confirm required standards before deployment:

- Region: `us-east-1`
- Cluster name: `project-bedrock-cluster`
- Namespace: `retail-app`
- Developer IAM user: `bedrock-dev-view`
- Project tag: `Project=Bedrock`

## 3) Terraform Backend Setup (S3 + DynamoDB)

Backend resources used:

- S3 bucket: `bedrock-terraform-state-alt-soe-025-1483`
- DynamoDB lock table: `bedrock-terraform-locks`

Optional helper scripts:

- Bash: `scripts/setup-backend.sh`
- PowerShell: `scripts/setup-backend.ps1`

Manual validation:

```bash
aws s3api get-bucket-versioning --bucket bedrock-terraform-state-alt-soe-025-1483
aws s3api get-bucket-encryption --bucket bedrock-terraform-state-alt-soe-025-1483
```

## 4) Deploy Infrastructure with Terraform

From `terraform/`:

1. Initialize:

```bash
terraform init
```

2. Validate and plan:

```bash
terraform validate
terraform plan
```

3. Apply:

```bash
terraform apply -auto-approve
```

4. Confirm no drift:

```bash
terraform plan
```

Expected result: `No changes. Your infrastructure matches the configuration.`

## 5) Configure kubectl for EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
kubectl get nodes
```

Expected: nodes in `Ready` state.

## 6) Verify aws-auth and RBAC Mapping

```bash
kubectl get configmap aws-auth -n kube-system -o yaml
```

Confirm:

- Node role mapping exists (`project-bedrock-cluster-node-group-role`)
- User mapping exists for `arn:aws:iam::816212136006:user/bedrock-dev-view`

## 7) Verify ALB Controller

```bash
kubectl get pods -n kube-system | grep -i aws-load-balancer-controller
```

Expected: controller pod(s) are `Running`.

## 8) Deploy Application (Helm, Step-by-Step)

### 8.1 Add/update chart repo

```bash
helm repo add retail-app https://aws.github.io/retail-store-sample-app
helm repo update
```

### 8.2 Deploy services

Use the working sequence with overrides:

```bash
helm upgrade --install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/ui-values.yaml --create-namespace --wait --timeout 10m
helm upgrade --install catalog oci://public.ecr.aws/aws-containers/retail-store-sample-catalog-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/catalog-values.yaml --wait --timeout 10m
helm upgrade --install orders oci://public.ecr.aws/aws-containers/retail-store-sample-orders-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/orders-values.yaml --wait --timeout 10m
helm upgrade --install cart oci://public.ecr.aws/aws-containers/retail-store-sample-cart-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/cart-values.yaml --wait --timeout 10m
helm upgrade --install checkout oci://public.ecr.aws/aws-containers/retail-store-sample-checkout-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/checkout-value.yaml --wait --timeout 10m
```

### 8.3 Validate releases and pods

```bash
helm list -n retail-app
kubectl get pods -n retail-app
kubectl get pvc -n retail-app
```

Expected: all releases `deployed`, pods `Running`, PVCs `Bound`.

## 9) Apply/Verify Ingress (ALB)

Apply ingress:

```bash
kubectl apply -f k8s/ingress.yaml
kubectl get ingress -n retail-app
kubectl describe ingress retail-app-ingress -n retail-app
```

Critical check:

- Ingress backend must route to service `ui` on port `80`.

## 10) End-to-End URL Validation

```bash
curl -I http://<alb-dns-name>
```

Expected: `HTTP/1.1 200 OK`.

## 10A) Deployment Commands and Their Uses

This section lists the commands used during deployment and exactly what each one does.

### Infrastructure provisioning commands

- `terraform init`  
	Initializes Terraform providers/modules and configures remote backend.

- `terraform validate`  
	Validates Terraform configuration syntax and internal consistency before planning.

- `terraform plan`  
	Shows what Terraform will create/update/destroy before apply.

- `terraform apply -auto-approve`  
	Applies planned infrastructure changes without interactive approval prompt.

### Cluster access and RBAC verification commands

- `aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster`  
	Configures local kubeconfig context to access the target EKS cluster.

- `kubectl get nodes`  
	Confirms worker nodes are registered and ready.

- `kubectl get configmap aws-auth -n kube-system -o yaml`  
	Verifies IAM role/user mappings into Kubernetes access.

- `kubectl get pods -n kube-system | grep -i aws-load-balancer-controller`  
	Confirms ALB controller pod is running and able to reconcile ingress resources.

### Helm application deployment commands

- `helm repo add retail-app https://aws.github.io/retail-store-sample-app`  
	Adds the retail app chart repository locally.

- `helm repo update`  
	Refreshes chart index so latest chart versions are resolvable.

- `helm upgrade --install ui oci://public.ecr.aws/aws-containers/retail-store-sample-ui-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/ui-values.yaml --create-namespace --wait --timeout 10m`  
	Deploys/updates UI service and waits for readiness.

- `helm upgrade --install catalog oci://public.ecr.aws/aws-containers/retail-store-sample-catalog-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/catalog-values.yaml --wait --timeout 10m`  
	Deploys/updates Catalog service with in-cluster MySQL settings.

- `helm upgrade --install orders oci://public.ecr.aws/aws-containers/retail-store-sample-orders-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/orders-values.yaml --wait --timeout 10m`  
	Deploys/updates Orders service with PostgreSQL/RabbitMQ settings.

- `helm upgrade --install cart oci://public.ecr.aws/aws-containers/retail-store-sample-cart-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/cart-values.yaml --wait --timeout 10m`  
	Deploys/updates Cart service and waits for rollout completion.

- `helm upgrade --install checkout oci://public.ecr.aws/aws-containers/retail-store-sample-checkout-chart --version 1.4.0 -n retail-app -f k8s/helm-overrides/checkout-value.yaml --wait --timeout 10m`  
	Deploys/updates Checkout service and waits for rollout completion.

### Post-deployment health commands

- `helm list -n retail-app`  
	Confirms all expected Helm releases are present and `deployed`.

- `kubectl get pods -n retail-app`  
	Confirms workloads are running and not crash-looping.

- `kubectl get pvc -n retail-app`  
	Confirms stateful PVCs are bound.

- `kubectl apply -f k8s/ingress.yaml`  
	Applies ALB ingress resource for external routing.

- `kubectl get ingress -n retail-app`  
	Retrieves ALB DNS hostname assigned to ingress.

- `kubectl describe ingress retail-app-ingress -n retail-app`  
	Shows backend service mapping, annotations, and ingress reconciliation details.

- `curl -I http://<alb-dns-name>`  
	Validates external HTTP response (target: `200 OK`).

## 11) Generate Grading Artifact

From `terraform/`:

```bash
terraform output -json > ../grading.json
```

Quick key check (root):

```bash
python - <<'PY'
import json
req=[
 'cluster_name','vpc_id','region','cluster_endpoint','public_subnet_ids','private_subnet_ids',
 'assets_bucket_name','lambda_function_name','cloudwatch_log_groups','view_logs_commands',
 'developer_access_key_id','developer_secret_access_key','configure_kubectl'
]
d=json.load(open('grading.json'))
print('missing:', [k for k in req if k not in d])
PY
```

Expected: `missing: []`.

## 12) CI/CD Pipeline (Grading-Critical)

Workflow file:

- `.github/workflows/terraform.yml`

Push/Merge to `main` must include this sequence:

1. `terraform init`
2. `terraform plan`
3. `terraform apply`
4. `helm upgrade --install retail ...`

Verify command presence quickly:

```bash
grep -E "terraform init|terraform plan|terraform apply|helm upgrade --install retail" .github/workflows/terraform.yml
```

## 13) Troubleshooting Shortlist

- `No configuration files`: run Terraform from `terraform/` directory.
- Helm timeout with pending DB pod: check PVC/storage class in overrides.
- ALB `503`: verify ingress backend service/port mapping and service endpoints.
- Access issues: re-check `aws-auth` mapping and kubeconfig context.

## 14) Final Submission Checklist

- [ ] Terraform plan shows no drift
- [ ] All retail-app Helm releases are deployed
- [ ] ALB endpoint returns HTTP 200
- [ ] `grading.json` exists at repository root with all required keys
- [ ] CI/CD workflow includes Terraform + Helm deploy sequence
