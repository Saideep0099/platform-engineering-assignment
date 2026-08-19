# Part I — Observability Strategy

## Layers and tools
| Layer | What | How |
|---|---|---|
| Infra (nodes) | CPU, memory, disk, network, node NotReady | CloudWatch agent + Prometheus node-exporter -> Grafana |
| Kubernetes | pod health, restarts, Pending pods, deployment availability, HPA activity | kube-state-metrics + metrics-server -> Prometheus -> Grafana |
| Application | request rate, error rate, latency (RED), availability | app `/metrics` (Prometheus client) + ALB metrics; SLO dashboards in Grafana |
| AWS managed | ALB (5xx, target health, latency), RDS (connections, CPU, storage, replica lag), Lambda (errors/throttles), S3 (4xx/5xx) | CloudWatch metrics, surfaced in Grafana via the CloudWatch datasource |
| Logs | app + system logs | Fluent Bit DaemonSet -> CloudWatch Logs -> subscription -> OpenSearch for search/analytics |

## How the three tools fit together
- **CloudWatch** = collection layer for all AWS-managed metrics + raw log sink
  + alarms on AWS-native signals (RDS storage, ALB 5xx).
- **OpenSearch** = log search and ad-hoc troubleshooting ("show me all 5xx with
  this trace id in the last 15 min"), plus dashboards on log-derived data.
- **Grafana** = single pane of glass: Prometheus + CloudWatch datasources,
  team dashboards, SLO views, and the alerting UI engineers actually look at.

During an incident: Grafana tells you *that* and *where* it's broken;
OpenSearch tells you *why* (the actual log lines); CloudWatch covers the
managed services you can't instrument yourself.

## Five production alerts (with rationale)
1. **App error rate**: 5xx > 2% of requests over 5 min — user-facing SLO breach; pages on-call.
2. **No ready pods / availability**: `kube_deployment_status_replicas_available < 2`
   for enrollment-service for 2 min — imminent or actual outage.
3. **CrashLoop/restart storm**: >3 container restarts in 10 min in any prod
   namespace — catches bad deploys before users do.
4. **RDS**: connections > 80% of max, or FreeStorageSpace < 15% — the two DB
   failure modes that take the whole app down and are cheap to catch early.
5. **p95 latency** > 800ms for 10 min — degradation alert (ticket, not page)
   that catches resource pressure, slow queries, Redis trouble before 503s.
(Plus node NotReady and HPA-at-max as warning-level alerts.)
