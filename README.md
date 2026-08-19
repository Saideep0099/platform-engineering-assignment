# Platform Engineering Assignment — AWS EKS Enrollment Platform

Production-oriented mini-platform for a containerized healthcare enrollment
service on AWS EKS: Terraform IaC, Helm, Jenkins CI, ArgoCD GitOps, IRSA
security, Python/shell operational automation, and full documentation.

## Repository map
| Path | What it covers |
|---|---|
| `architecture/` | Part A — diagram + design decisions |
| `terraform/` | Part B — modules (vpc/eks/iam/ecr/rds) + dev/prod environments |
| `application/` | FastAPI enrollment service + tests + Dockerfile |
| `helm/enrollment-service/` | Part C — full chart (deployment, svc, ingress, SA, configmap, HPA, PDB) |
| `docs/iam-irsa.md` | Part D — IRSA design + why not static keys |
| `cicd/Jenkinsfile` + `docs/cicd-gitops.md` | Part E — pipeline + GitOps rationale |
| `docs/troubleshooting.md` | Part F — 503 incident runbook |
| `scripts/health_check.py` | Part G — EKS health report utility |
| `scripts/pre_deploy.sh` | Part H — pre-deployment validation |
| `docs/observability.md` | Part I — monitoring strategy + 5 alerts |
| `docs/modernization.md` | Part J — EC2 -> EKS migration |
| `docs/platform-strategy.md` | Part K — golden path for 8 teams |
| `docs/leadership.md` | Part L — leadership scenarios |
| `gitops/` | ArgoCD Applications + env values |

## Quick start

### Application (local)
```bash
cd application
pip install -r requirements.txt pytest httpx
pytest tests -q
uvicorn src.main:app --port 8080
curl localhost:8080/health
```

### Infrastructure (per environment)
```bash
cd terraform/environments/dev
terraform init          # S3 backend + DynamoDB locking (see backend.tf)
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
> Where real provisioning isn't possible, the code is complete and plan-able;
> account IDs / SG IDs / cert ARNs are marked REPLACE and would come from
> outputs or a data source in a live account.

### Helm (render / install)
```bash
helm template enrollment helm/enrollment-service --set image.tag=abc12345-1
helm upgrade --install enrollment helm/enrollment-service \
  -n enrollment --create-namespace --set image.tag=abc12345-1
```
(In practice ArgoCD performs this — see `gitops/`.)

### Operational scripts
```bash
pip install kubernetes
python scripts/health_check.py --namespace enrollment       # exit 0/1/2
CLUSTER_NAME=dev-platform-eks NAMESPACE=enrollment ./scripts/pre_deploy.sh
```

## How multiple teams consume the platform (Terraform extension)
Modules are consumed, not copied. A team onboarding is one composition block:
```hcl
module "team_claims" {
  source        = "../../modules/team"     # wraps iam + ecr + namespace quota
  team          = "claims"
  irsa_bindings = { "claims-api" = data.aws_iam_policy_document.claims_s3.json }
}
```
Shared modules are versioned (git tags / a module registry), so teams pin
versions and upgrade deliberately. Environment differences live only in
`environments/*/terraform.tfvars`; state is isolated per environment with its
own S3 key and DynamoDB lock, so a dev mistake can't touch prod state.

## Zero-downtime deployments (defended in Part C)
- Rolling update `maxSurge: 1 / maxUnavailable: 0` — capacity never drops.
- Readiness probe gates traffic; a bad build never receives requests.
- `preStop` sleep + graceful uvicorn shutdown lets the ALB drain in-flight requests.
- PodDisruptionBudget `minAvailable: 2` protects against node drains.
- Topology spread across AZs; HPA min 3 replicas in prod.
- Immutable image tags + GitOps make rollback a one-line `git revert`.
