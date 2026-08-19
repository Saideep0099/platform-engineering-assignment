# Part F — Production Troubleshooting Runbook: HTTP 503

Symptom: users get 503s; ALB itself is healthy; only some requests fail.
"Some requests" is the key clue — it usually means a *subset of targets*
(pods) is unhealthy, and the ALB is routing a fraction of traffic to them
before health checks eject them, or the Service has fewer ready endpoints
than expected.

## Step-by-step (follow the request path top-down)

### 1. Scope the blast radius (2 min)
- Grafana: error-rate panel — which %, since when, correlated with a deploy?
- ALB access logs (Athena/OpenSearch): are 503s `elb_status_code` (no healthy
  target / target deregistered) or `target_status_code` (app returned 503)?
  This one distinction splits the whole investigation:
  - **ELB-generated 503** -> target group has no/insufficient healthy targets -> go to steps 3–5.
  - **Target-generated 503** -> the app itself is throwing -> go to steps 6–7.

### 2. Was anything just deployed?
`argocd app history enrollment-service-prod` / check GitOps repo log.
If yes and errors started at sync time -> rollback first, investigate after
(see rollback decision in docs/leadership.md).

### 3. Pods
```
kubectl -n enrollment get pods -o wide
kubectl -n enrollment describe pod <bad-pod>
kubectl -n enrollment logs <bad-pod> --previous
kubectl top pods -n enrollment
```
Distinguish:
- **CrashLoopBackOff** -> app failure: read `logs --previous` for the crash cause.
- **Running but 0/1 Ready** -> failed readiness probe: `describe pod` shows probe
  failures; curl the probe path from another pod to confirm.
- **OOMKilled** in `describe` (last state, exit code 137) -> insufficient memory limit.
- **Pending** -> `describe` events: Insufficient cpu/memory (node capacity) or
  node failure -> `kubectl get nodes`, `kubectl describe node`.

### 4. Service and endpoints
```
kubectl -n enrollment get svc enrollment-service -o yaml
kubectl -n enrollment get endpoints enrollment-service
```
- **Empty/short endpoints with Running pods** -> selector mismatch: diff
  `spec.selector` on the Service vs pod labels. This exact failure produces
  intermittent 503s when only some pods match.
- Endpoints only contain **Ready** pods — so failed readiness probes shrink
  this list even though pods look "Running".

### 5. Ingress / ALB wiring
```
kubectl -n enrollment get ingress enrollment-service -o yaml
kubectl -n platform logs deploy/aws-load-balancer-controller
```
- Target group health in AWS console: which targets unhealthy, and why
  (timeout vs 4xx/5xx on health check path)?
- **Security group issue**: node SG must allow the ALB SG on the pod port
  (target-type: ip registers pod IPs directly). A recently "tightened" SG
  rule causing health-check timeouts is a classic cause.

### 6. Application layer
- App logs in OpenSearch filtered to 5xx: stack traces? timeouts?
- If errors are DB-related: connection pool exhausted, "too many connections",
  auth failures after a secret rotation.

### 7. Dependencies
- **RDS**: CloudWatch `DatabaseConnections`, CPU, `FreeableMemory`; RDS events
  (failover?). Test from a debug pod:
  `kubectl run tmp --rm -it --image=postgres:16 -- psql $DSN -c 'select 1'`
- **Redis**: ElastiCache CPU/evictions/connection count; `redis-cli PING` from
  a debug pod. Timeouts to Redis often surface as slow requests -> readiness
  probe timeouts -> pods ejected -> 503s (a cascading pattern worth naming
  in the review).

## Fast diagnosis table

| Cause | Telltale signal |
|---|---|
| Application failure | CrashLoopBackOff + stack trace in `logs --previous` |
| Failed readiness probe | Pod Running, 0/1 Ready, probe failures in `describe` |
| Wrong Service selector | Pods healthy but `get endpoints` empty/short |
| Insufficient resources | OOMKilled/exit 137, or Pending with "Insufficient cpu" |
| Node failure | `get nodes` NotReady; pods on that node Unknown |
| SG/network issue | ALB target health = timeout; no request ever hits app logs |
| ALB/Ingress config | Controller logs show reconcile errors; wrong health path |
| Database | App logs show DB errors; RDS connection/CPU metrics spike |
| Redis | Slow requests + probe timeouts; ElastiCache evictions/CPU |
