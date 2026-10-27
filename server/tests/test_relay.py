from fastapi.testclient import TestClient

from app.main import create_app

OWNER = "owner-token-0123456789"
TAG = "a" * 64


def fp(device, value):
    return {"device_id": device, "doc": TAG, "fields": {"b" * 64: value * 64}}


def test_other_device_sees_changes_but_sender_does_not():
    c = TestClient(create_app())
    assert c.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "c")).json() == {"seq": 1}
    got = c.get(f"/v1/{OWNER}/changes", params={"device_id": "phone"}).json()["changes"]
    assert len(got) == 1 and got[0]["doc"] == TAG
    assert c.get(f"/v1/{OWNER}/changes", params={"device_id": "laptop"}).json()["changes"] == []


def test_since_filters_old_entries():
    c = TestClient(create_app())
    c.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "c"))
    c.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "d"))
    got = c.get(f"/v1/{OWNER}/changes", params={"device_id": "phone", "since": 1}).json()["changes"]
    assert [e["seq"] for e in got] == [2]


def test_owners_are_isolated():
    c = TestClient(create_app())
    c.post(f"/v1/{OWNER}/fingerprints", json=fp("laptop", "c"))
    other = c.get("/v1/someone-else-0123456789/changes", params={"device_id": "phone"}).json()
    assert other["changes"] == []


def test_rejects_short_owner_token_and_bad_tag():
    c = TestClient(create_app())
    assert c.post("/v1/short/fingerprints", json=fp("laptop", "c")).status_code == 422
    bad = {"device_id": "laptop", "doc": "tooshort", "fields": {}}
    assert c.post(f"/v1/{OWNER}/fingerprints", json=bad).status_code == 422
