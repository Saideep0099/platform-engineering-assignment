# Part E — CI/CD & GitOps

## What happens on commit
1. Webhook triggers Jenkins: checkout -> unit tests -> SonarQube quality gate
   -> Trivy source scan -> docker build -> Trivy image scan -> push to ECR.
2. Jenkins commits the new image tag into the GitOps repo (dev values file).
3. ArgoCD detects drift between Git and cluster, syncs, EKS rolls the deployment.

## Image versioning
`<git-short-sha>-<build-number>` with ECR tag immutability ON. Every running
pod is traceable to an exact commit; a tag can never be silently overwritten;
`:latest` is banned (the Helm chart *requires* an explicit tag).

## Promotion
Promotion = moving a *proven artifact*, never rebuilding:
dev (auto) -> QA (auto-PR, merged after tests) -> prod (PR + human review +
manual ArgoCD sync). Same image digest travels through all three environments;
only the values files differ.

## Roles
- **Jenkins = CI**: builds, tests, scans, publishes artifacts, edits Git.
  It has NO kubeconfig and no cluster credentials.
- **ArgoCD = CD**: the only actor with cluster write access; continuously
  reconciles cluster state to Git; self-heals manual drift; one-click rollback
  (revert the Git commit).

## Why GitOps instead of Jenkins deploying directly
- **Single source of truth + audit trail**: every prod change is a Git commit
  with author, review, and timestamp — crucial for healthcare/gov compliance.
- **Credential surface**: cluster admin creds don't live in CI, which is the
  most-attacked, most-plugin-riddled system in most orgs.
- **Drift correction**: ArgoCD reverts out-of-band `kubectl edit`; Jenkins-push
  deploys can't detect drift at all.
- **Disaster recovery**: rebuild a cluster and point ArgoCD at the repo —
  everything comes back.
- **Rollback = `git revert`**, reviewable like any other change.

## Environments
One GitOps repo, one overlay per environment (values-dev/qa/prod), one ArgoCD
Application each. Dev/QA can share a cluster with separate namespaces; prod is
its own cluster + AWS account, provisioned from the same Terraform modules with
its own tfvars and state file.
