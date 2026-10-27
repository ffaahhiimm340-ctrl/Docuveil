import pytest
from fastapi.testclient import TestClient

from app.main import MemoryStore, create_app
from app.store_sql import SqlStore

OWNER = "owner-token-0123456789"
TAG = "a" * 64


def fp(device, value):
    return {"device_id": device, "doc": TAG, "fields": {"b" * 64: value * 64}}


@pytest.fixture(params=["memory", "sql"])
def client(request):
    store = MemoryStore() if request.param == "memory" else SqlStore("sqlite://")
    return TestClient(create_app(store))


def test_other_device_sees_changes_but_sender_does_not(client):
    assert client.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "c")).json() == {"seq": 1}
    got = client.get(f"/v1/{OWNER}/changes", params={"device_id": "phone"}).json()["changes"]
    assert len(got) == 1 and got[0]["doc"] == TAG
    assert client.get(f"/v1/{OWNER}/changes", params={"device_id": "laptop"}).json()["changes"] == []


def test_since_filters_old_entries(client):
    client.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "c"))
    client.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "d"))
    got = client.get(f"/v1/{OWNER}/changes", params={"device_id": "phone", "since": 1}).json()["changes"]
    assert [e["seq"] for e in got] == [2]


def test_owners_are_isolated(client):
    client.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "c"))
    other = client.get("/v1/someone-else-0123456789/changes", params={"device_id": "phone"}).json()
    assert other["changes"] == []


def test_fields_round_trip_exactly(client):
    body = fp("laptop", "c")
    client.post(f"/v1/{OWNER}/fingerprints", json=body)
    got = client.get(f"/v1/{OWNER}/changes", params={"device_id": "phone"}).json()["changes"][0]
    assert got["fields"] == body["fields"] and got["device_id"] == "laptop"


def test_rejects_short_owner_token_and_bad_tag(client):
    assert client.post("/v1/short/fingerprints", json=fp("laptop", "c")).status_code == 422
    bad = {"device_id": "laptop", "doc": "tooshort", "fields": {}}
    assert client.post(f"/v1/{OWNER}/fingerprints", json=bad).status_code == 422
