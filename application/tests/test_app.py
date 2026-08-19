from fastapi.testclient import TestClient
from src.main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_create_and_get():
    r = client.post("/enrollments", json={"member_name": "Jane Doe", "plan_id": "GOLD-1"})
    assert r.status_code == 201
    eid = r.json()["id"]
    r2 = client.get(f"/enrollments/{eid}")
    assert r2.status_code == 200
    assert r2.json()["member_name"] == "Jane Doe"


def test_get_missing_returns_404():
    assert client.get("/enrollments/nope").status_code == 404
