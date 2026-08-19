# Part D — IAM & IRSA

## The chain
Pod -> projected ServiceAccount token -> AWS SDK calls `sts:AssumeRoleWithWebIdentity`
-> EKS OIDC provider validates the token -> STS returns short-lived credentials
for the IAM role -> pod reads `s3://<env>-enrollment-docs/enrollments/*`.

## The pieces (all in Terraform)
- **OIDC provider** (`modules/eks`): registers the cluster's OIDC issuer with IAM
  so IAM can verify ServiceAccount tokens.
- **IAM role + trust policy** (`modules/iam`): trust is conditioned on BOTH
  `sub = system:serviceaccount:enrollment:enrollment-service` and
  `aud = sts.amazonaws.com`. Only that exact SA in that exact namespace can
  assume the role — another team's pod cannot.
- **Least-privilege policy**: `s3:GetObject` on one prefix + `s3:ListBucket`
  restricted with an `s3:prefix` condition. No write, no delete, no other buckets.
- **Kubernetes ServiceAccount** (Helm chart): annotated with
  `eks.amazonaws.com/role-arn`. The EKS pod identity webhook injects
  `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE`; the AWS SDK picks them
  up automatically — zero application code changes.

## Why not an access key in a Kubernetes Secret?
1. **Static & long-lived** — leaked once, valid until someone notices and rotates.
   IRSA credentials expire in ~1 hour and rotate automatically.
2. **Broad exposure** — anyone with read on Secrets in the namespace (or a
   compromised pod, or an etcd backup) gets the key. K8s Secrets are only
   base64, not encryption.
3. **Rotation is manual** and usually forgotten; rotation breaks running pods
   unless carefully choreographed.
4. **No identity attribution** — CloudTrail shows "the shared key" instead of
   "the enrollment-service role", killing auditability (a real problem in a
   healthcare/government context).
5. **Blast radius** — keys tend to accumulate permissions; an IRSA role is
   scoped per-workload by construction.
