# Part K — Developer Platform / Golden Path (8 teams)

## Goal
A new team goes from "we have a repo" to "we're deployed to dev with dashboards
and alerts" in under a day, with near-zero platform-team involvement.

## Reusable components
1. **Application template repo** (`cookiecutter`/Backstage scaffolder):
   Dockerfile, standard Helm chart *as a dependency* (teams override values,
   not templates), Jenkinsfile from a shared library, `catalog-info` metadata.
2. **Shared Helm library chart**: probes, resources, SA/IRSA, PDB, HPA,
   security context all pre-wired. Teams supply image, env, ingress host.
   One place to fix a platform-wide issue (e.g., new PodSecurity standard).
3. **Jenkins shared library**: teams' Jenkinsfiles are ~10 lines calling
   `standardPipeline(service: 'x')` — scanning and quality gates can't be
   skipped because they're inside the library.
4. **Terraform "team onboarding" module**: one `module "team_claims" {}` block
   creates: namespace (via GitOps), ResourceQuota/LimitRange, IRSA roles from a
   declared list of AWS permissions, ECR repos, log groups, and a Grafana folder.
5. **ArgoCD ApplicationSet**: watches `apps/*/overlays/*` in the GitOps repo —
   a merged PR adding a folder IS the onboarding of a new app.
6. **Observability by default**: Fluent Bit + Prometheus scrape annotations in
   the library chart; a templated Grafana dashboard and baseline alerts stamped
   out per service.
7. **Secrets path**: ExternalSecret template + a documented Secrets Manager
   naming convention (`/{env}/{team}/{app}/...`) that the IRSA policy scopes to.

## Onboarding flow
Team runs the scaffolder -> opens 2 PRs (app repo, GitOps repo) -> platform
team reviews the *first* onboarding for a team, then it's self-service.
Docs + a #platform-help channel + office hours cover the rest.

## What stays centralized
Cluster lifecycle, node groups, ingress/ALB controller, ArgoCD, base networking,
org-wide policies (OPA/Kyverno: no :latest, resource limits required, non-root).
Teams own everything inside their namespace.
