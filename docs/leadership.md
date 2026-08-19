# Part L — Leadership & Production Ownership

## Scenario 1 — Critical production deployment fails on-call
1. **Assess impact (first 5 min)**: user-facing or internal? Error rate,
   affected endpoints, blast radius from Grafana/ALB metrics. Declare severity.
2. **Communicate early, before you know everything**: post in the incident
   channel — what's known, impact, who's on it, next update time (every
   15–30 min). Stakeholders forgive outages; they don't forgive silence.
3. **Coordinate**: I run the incident (comms + decisions); pull in the deploying
   developer for app context — but one person owns the incident.
4. **Rollback decision — bias to rollback**: if the failure correlates with the
   deploy and rollback is safe (no irreversible schema migration ran), roll back
   first and diagnose later. Restore-then-root-cause. The exception: when the
   deploy included a non-backward-compatible data change — then roll forward
   with a fix, which is why we require backward-compatible migrations.
5. **Restore & verify**: confirm error rate returns to baseline, close comms
   with a summary.
6. **Blameless post-incident review** within 48h: timeline, contributing
   factors, action items with owners. Focus on the system that allowed the
   failure (missing test, missing alert, gap in the pipeline), never the person.

## Scenario 2 — Team wants to bypass the standard deployment process
First, listen — "the process is slow" is *data about my platform*. Sit with
them, measure where their time actually goes (queue time? flaky tests? slow
scans? approval waits?). Usually the friction is fixable: parallelize stages,
cache builds, pre-approved change classes for low-risk deploys.
What I hold firm on: the *invariants* (scanning, review, GitOps audit trail —
non-negotiable in healthcare/gov), not the *implementation*. If they need an
emergency path, we build a documented break-glass process with automatic
post-hoc review rather than letting an unofficial bypass grow in the dark.
Outcome: their cycle time improves inside the paved road, and the paved road
gets better for all 8 teams.

## Scenario 3 — Standardization without becoming a bottleneck
- Standards as *defaults, not gates*: golden templates that are genuinely the
  easiest option win adoption without mandates.
- A lightweight RFC process where team representatives co-own the standards —
  people follow rules they helped write.
- Enforce only the floor automatically (policy-as-code: Kyverno/OPA, tflint,
  pipeline library) so no human review is needed for compliance.
- Grandfather existing divergence with a migration path and platform-team help,
  rather than demanding big-bang rewrites.
- Publish a "supported vs. tolerated vs. deprecated" matrix so teams know the
  cost of going off-road: they can, but they own the support burden.

## Scenario 4 — Junior engineer repeatedly breaking Terraform
Protect production with *systems*, then grow the person inside them:
1. Guardrails first: plan-only in CI with required review, `prevent_destroy` on
   critical resources, separate state/credentials per environment, sandbox
   account where they can apply freely.
2. Diagnose the mistake pattern — is it Terraform mechanics, our module
   conventions, or missing review? Pair on the next 2–3 changes; review *plans*
   together, not just code, because the plan is where Terraform surprises live.
3. Give progressively larger scoped work (dev-only modules -> shared modules)
   with explicit success criteria.
4. Turn their mistakes into platform fixes: every incident they cause reveals a
   missing guardrail. A junior who can break prod is a process gap, not a
   people problem.
