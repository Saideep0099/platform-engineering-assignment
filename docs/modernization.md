# Part J — Legacy Application Modernization (EC2 -> EKS)

## Guiding principle
Migrate the *application*, not the infrastructure habits. Anything AWS runs
better as a managed service stays a managed service:
- **Redis -> ElastiCache** (not Redis-in-a-pod): managed failover, backups,
  patching. Running stateful Redis on K8s adds operational risk for zero gain.
- **Database -> RDS**: same reasoning. Pods connect via SG-restricted endpoint;
  credentials from Secrets Manager via External Secrets Operator.
- Only the app processes and batch jobs move into the cluster.

## Component-by-component
| Legacy | Target | Why |
|---|---|---|
| Stateless request handlers | Deployment + HPA | The easy 80% — containerize first |
| Local file storage | **S3 if write-once/read-many (documents, exports); EFS (PVC via EFS CSI) only if the app needs POSIX file semantics across pods** | S3 is cheaper, more durable, and removes the volume from the pod lifecycle; EFS is the compatibility escape hatch when refactoring to S3 isn't feasible yet |
| Scheduled batch (cron) | Kubernetes CronJobs | Versioned with the app, same image, same observability; `concurrencyPolicy: Forbid` to match single-host cron semantics |
| Local log files | stdout -> Fluent Bit -> CloudWatch/OpenSearch | App must be changed to log to stdout — this is usually the first code change required |
| Config files on disk | ConfigMaps (non-secret) / External Secrets (secret) | 12-factor: same image across environments |
| Stateful in-process state (sessions, caches) | Externalize to Redis | Prerequisite for >1 replica and rolling deploys |

## Migration sequence (zero/minimal downtime)
1. **Strangler pattern behind the existing entry point**: put ALB in front of
   the EC2 app first (if not already).
2. Containerize; deploy to EKS in parallel, pointing at the *same* RDS/Redis.
3. **Weighted target groups**: shift 5% -> 25% -> 50% -> 100% of ALB traffic to
   the EKS target group, watching error rate/latency at each step.
4. Move batch jobs last (they're the easiest to run twice by accident — disable
   the EC2 cron in the same change that enables the CronJob).
5. Keep the EC2 ASG at capacity but 0% weight for a bake period.

## Rollback strategy
Rollback = flip the ALB weight back to EC2 (seconds, no redeploy). This is the
main reason to migrate via weighted routing rather than a cutover. Data-layer
rollback isn't needed because both stacks share RDS/Redis — which is also why
schema changes are frozen during the traffic-shift window.
