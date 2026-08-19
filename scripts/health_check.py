#!/usr/bin/env python3
"""EKS Application Health Report.

Queries the Kubernetes API for deployments and pods in one or more
namespaces, flags unhealthy pods (CrashLoopBackOff, ImagePullBackOff,
Pending, NotReady), prints a summary report, and exits non-zero on
failure so it can gate a CI/CD pipeline.

Usage:
    python health_check.py --namespace enrollment [--namespace other] [--json]

Exit codes:
    0 = all healthy   1 = unhealthy workloads found   2 = execution error
"""
import argparse
import json
import logging
import sys

try:
    from kubernetes import client, config
    from kubernetes.client.rest import ApiException
except ImportError:
    print("Install dependency: pip install kubernetes", file=sys.stderr)
    sys.exit(2)

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("health-check")

BAD_WAITING_REASONS = {"CrashLoopBackOff", "ImagePullBackOff", "ErrImagePull", "CreateContainerConfigError"}


def load_kube_config() -> None:
    """In-cluster config when running as a Job/CronJob, kubeconfig otherwise."""
    try:
        config.load_incluster_config()
        log.info("Loaded in-cluster config")
    except config.ConfigException:
        config.load_kube_config()
        log.info("Loaded local kubeconfig")


def pod_status(pod) -> tuple[str, bool]:
    """Return (display_state, is_healthy) for a pod."""
    phase = pod.status.phase or "Unknown"
    if phase == "Pending":
        return "Pending", False

    ready = False
    for cond in pod.status.conditions or []:
        if cond.type == "Ready" and cond.status == "True":
            ready = True

    for cs in pod.status.container_statuses or []:
        waiting = cs.state.waiting
        if waiting and waiting.reason in BAD_WAITING_REASONS:
            return waiting.reason, False

    if phase == "Running" and not ready:
        return "Running/NotReady", False
    if phase in ("Failed", "Unknown"):
        return phase, False
    return phase, ready


def check_namespace(apps_v1, core_v1, namespace: str) -> dict:
    result = {"namespace": namespace, "deployments": [], "healthy": True}

    deployments = apps_v1.list_namespaced_deployment(namespace).items
    pods = core_v1.list_namespaced_pod(namespace).items

    for dep in deployments:
        desired = dep.spec.replicas or 0
        available = dep.status.available_replicas or 0
        selector = dep.spec.selector.match_labels or {}
        dep_pods = [
            p for p in pods
            if selector.items() <= (p.metadata.labels or {}).items()
        ]

        pod_rows, dep_healthy = [], available >= desired
        for p in dep_pods:
            state, ok = pod_status(p)
            pod_rows.append({"name": p.metadata.name, "state": state, "ready": ok,
                             "restarts": sum(cs.restart_count for cs in (p.status.container_statuses or []))})
            dep_healthy = dep_healthy and ok

        result["deployments"].append({
            "name": dep.metadata.name, "desired": desired,
            "available": available, "healthy": dep_healthy, "pods": pod_rows,
        })
        result["healthy"] = result["healthy"] and dep_healthy

    return result


def print_report(results: list[dict]) -> None:
    print("EKS Application Health Report")
    print("-----------------------------")
    for ns in results:
        print(f"\nNamespace: {ns['namespace']}")
        for dep in ns["deployments"]:
            print(f"\nDeployment: {dep['name']}")
            print(f"Desired Replicas : {dep['desired']}")
            print(f"Available        : {dep['available']}")
            print("\nPods:")
            for p in dep["pods"]:
                ready = "Ready" if p["ready"] else "NOT READY"
                print(f"  {p['name']:<40} {p['state']:<20} {ready}  (restarts: {p['restarts']})")
    overall = all(ns["healthy"] for ns in results)
    print(f"\nOverall Status: {'PASSED' if overall else 'FAILED'}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--namespace", action="append", required=True)
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    args = parser.parse_args()

    try:
        load_kube_config()
        apps_v1, core_v1 = client.AppsV1Api(), client.CoreV1Api()
        results = [check_namespace(apps_v1, core_v1, ns) for ns in args.namespace]
    except ApiException as e:
        log.error("Kubernetes API error: %s %s", e.status, e.reason)
        return 2
    except Exception:
        log.exception("Unexpected error")
        return 2

    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print_report(results)

    return 0 if all(ns["healthy"] for ns in results) else 1


if __name__ == "__main__":
    sys.exit(main())
