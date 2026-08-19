#!/usr/bin/env bash
# Pre-deployment validation. Fails fast (and safely) if any prerequisite
# is missing. Intended to run as the first stage of a deploy job.
set -euo pipefail

EXPECTED_ACCOUNT="${EXPECTED_ACCOUNT:-123456789012}"
CLUSTER_NAME="${CLUSTER_NAME:-dev-platform-eks}"
NAMESPACE="${NAMESPACE:-enrollment}"
ECR_REGISTRY="${ECR_REGISTRY:-123456789012.dkr.ecr.us-east-1.amazonaws.com}"
AWS_REGION="${AWS_REGION:-us-east-1}"

PASS=0; FAIL=0
ok()   { echo "  [OK]   $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "=== Pre-deployment validation ==="

# 1. Tooling
command -v aws     >/dev/null 2>&1 && ok "aws CLI found ($(aws --version 2>&1 | cut -d' ' -f1))" || fail "aws CLI not installed"
command -v kubectl >/dev/null 2>&1 && ok "kubectl found"  || fail "kubectl not installed"

# 2. AWS identity — refuse to run against the wrong account
if ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
  if [[ "$ACCOUNT" == "$EXPECTED_ACCOUNT" ]]; then
    ok "AWS account $ACCOUNT matches expected"
  else
    fail "AWS account $ACCOUNT != expected $EXPECTED_ACCOUNT — aborting to protect the wrong environment"
  fi
else
  fail "No valid AWS credentials"
fi

# 3. Kubernetes context — must point at the intended cluster
CONTEXT=$(kubectl config current-context 2>/dev/null || true)
if [[ "$CONTEXT" == *"$CLUSTER_NAME"* ]]; then
  ok "kubectl context '$CONTEXT' targets $CLUSTER_NAME"
else
  fail "kubectl context '$CONTEXT' does not match cluster $CLUSTER_NAME"
fi

# 4. EKS cluster reachable and ACTIVE
STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" \
           --query 'cluster.status' --output text 2>/dev/null || true)
[[ "$STATUS" == "ACTIVE" ]] && ok "EKS cluster $CLUSTER_NAME is ACTIVE" || fail "EKS cluster status: ${STATUS:-unreachable}"

# 5. API server responds
kubectl get --raw=/readyz >/dev/null 2>&1 && ok "Kubernetes API is ready" || fail "Kubernetes API not responding"

# 6. Namespace exists
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 && ok "Namespace '$NAMESPACE' exists" || fail "Namespace '$NAMESPACE' missing"

# 7. Required resources in namespace
for res in "serviceaccount/enrollment-service" "configmap/enrollment-service-config"; do
  kubectl -n "$NAMESPACE" get "$res" >/dev/null 2>&1 && ok "$res present" || fail "$res missing in $NAMESPACE"
done

# 8. Container registry reachable + authenticated
if aws ecr get-login-password --region "$AWS_REGION" >/dev/null 2>&1 \
   && aws ecr describe-repositories --region "$AWS_REGION" \
        --repository-names enrollment-service >/dev/null 2>&1; then
  ok "ECR registry $ECR_REGISTRY reachable, repo exists"
else
  fail "Cannot reach/authenticate to ECR or repo missing"
fi

echo
echo "Result: $PASS passed, $FAIL failed"
if (( FAIL > 0 )); then
  echo "Pre-deployment validation FAILED — deployment blocked."
  exit 1
fi
echo "All prerequisites satisfied — safe to deploy."
