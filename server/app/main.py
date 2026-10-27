"""Thin relay for keyed fingerprints. It stores only opaque HMAC tags.

The server never gets document content, field names or plain hashes. It does
see which device sent a message and when; state that in the paper's threat model.
Storage is behind `Store` so PostgreSQL can replace the in-memory version.
"""

import os
import time
from typing import Protocol

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


class FingerprintIn(BaseModel):
    device_id: str = Field(min_length=1, max_length=64)
    doc: str = Field(min_length=64, max_length=64)  # hex HMAC-SHA256 tag
    fields: dict[str, str]  # field tag -> value tag


class Store(Protocol):
    def put(self, owner: str, fp: FingerprintIn) -> int: ...
    def changes(self, owner: str, since: int, device_id: str) -> list[dict]: ...


class MemoryStore:
    """Per-owner append-only log. `owner` is a pairing token chosen by the app."""

    def __init__(self) -> None:
        self.log: dict[str, list[dict]] = {}

    def put(self, owner: str, fp: FingerprintIn) -> int:
        entries = self.log.setdefault(owner, [])
        entries.append({"seq": len(entries) + 1, "ts": time.time(), **fp.model_dump()})
        return len(entries)

    def changes(self, owner: str, since: int, device_id: str) -> list[dict]:
        return [e for e in self.log.get(owner, []) if e["seq"] > since and e["device_id"] != device_id]


def create_app(store: Store | None = None) -> FastAPI:
    app = FastAPI(title="Docuveil relay")
    st = store or MemoryStore()

    @app.get("/health")
    def health() -> dict:
        return {"ok": True}

    @app.post("/v1/{owner}/fingerprints")
    def post_fingerprint(owner: str, fp: FingerprintIn) -> dict:
        if not (16 <= len(owner) <= 128):
            raise HTTPException(422, "owner token must be 16-128 characters")
        return {"seq": st.put(owner, fp)}

    @app.get("/v1/{owner}/changes")
    def get_changes(owner: str, device_id: str, since: int = 0) -> dict:
        """Fingerprints sent by the owner's other devices after `since`; the
        app compares them with its own and decides whether to alert."""
        return {"changes": st.changes(owner, since, device_id)}

    return app


def _default_store() -> Store:
    """PostgreSQL (or any SQLAlchemy URL) when DATABASE_URL is set, else memory."""
    url = os.environ.get("DATABASE_URL")
    if not url:
        return MemoryStore()
    from .store_sql import SqlStore

    return SqlStore(url)


app = create_app(_default_store())
