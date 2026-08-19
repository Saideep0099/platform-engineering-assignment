"""Enrollment Service — minimal FastAPI app.

The platform is the point of the assignment; the app just needs to be a
well-behaved Kubernetes citizen: health endpoints, config from env,
graceful shutdown, structured logs to stdout.
"""
import logging
import os
import uuid
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format='{"ts":"%(asctime)s","level":"%(levelname)s","msg":"%(message)s"}',
)
log = logging.getLogger("enrollment")

app = FastAPI(title="Enrollment Service", version=os.getenv("APP_VERSION", "dev"))

# In-memory store; real implementation uses RDS via env-provided DSN
_DB: dict[str, dict] = {}


class EnrollmentIn(BaseModel):
    member_name: str = Field(min_length=1, max_length=200)
    plan_id: str = Field(min_length=1, max_length=50)


@app.get("/health")
def health():
    """Liveness + readiness. In a real service, readiness would also
    check DB/Redis connectivity so the pod is pulled from the Service
    endpoints when a dependency is down."""
    return {"status": "ok", "version": app.version}


@app.post("/enrollments", status_code=201)
def create_enrollment(body: EnrollmentIn):
    eid = str(uuid.uuid4())
    record = {
        "id": eid,
        "member_name": body.member_name,
        "plan_id": body.plan_id,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    _DB[eid] = record
    log.info(f"enrollment created id={eid}")
    return record


@app.get("/enrollments/{enrollment_id}")
def get_enrollment(enrollment_id: str):
    record = _DB.get(enrollment_id)
    if not record:
        raise HTTPException(status_code=404, detail="enrollment not found")
    return record
