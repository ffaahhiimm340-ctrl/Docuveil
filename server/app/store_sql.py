"""SQL-backed store: PostgreSQL in deployment, SQLite for local tests.

Holds opaque tags only (see main.py). `seq` is a global autoincrement id, so
it only ever grows; clients ask for entries with seq greater than the last
one they saw, which is all they need.
"""

import json
import time

from sqlalchemy import Column, Float, Integer, String, Text, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Session

from .main import FingerprintIn


class Base(DeclarativeBase):
    pass


class FingerprintRow(Base):
    __tablename__ = "fingerprints"

    seq = Column(Integer, primary_key=True, autoincrement=True)
    owner = Column(String(128), nullable=False, index=True)
    ts = Column(Float, nullable=False)
    device_id = Column(String(64), nullable=False)
    doc = Column(String(64), nullable=False)
    fields = Column(Text, nullable=False)  # JSON {fieldTag: valueTag}


class SqlStore:
    def __init__(self, url: str) -> None:
        # `postgresql+psycopg://user:pw@host/db` or `sqlite://` (in-memory).
        kwargs = {}
        if url.startswith("sqlite") and ":memory:" in url or url == "sqlite://":
            from sqlalchemy.pool import StaticPool

            kwargs = {"connect_args": {"check_same_thread": False}, "poolclass": StaticPool}
        self.engine = create_engine(url, **kwargs)
        Base.metadata.create_all(self.engine)

    def put(self, owner: str, fp: FingerprintIn) -> int:
        with Session(self.engine) as s:
            row = FingerprintRow(
                owner=owner, ts=time.time(), device_id=fp.device_id, doc=fp.doc,
                fields=json.dumps(fp.fields),
            )
            s.add(row)
            s.commit()
            return row.seq

    def changes(self, owner: str, since: int, device_id: str) -> list[dict]:
        with Session(self.engine) as s:
            rows = s.scalars(
                select(FingerprintRow)
                .where(FingerprintRow.owner == owner, FingerprintRow.seq > since,
                       FingerprintRow.device_id != device_id)
                .order_by(FingerprintRow.seq)
            ).all()
            return [
                {"seq": r.seq, "ts": r.ts, "device_id": r.device_id, "doc": r.doc,
                 "fields": json.loads(r.fields)}
                for r in rows
            ]
