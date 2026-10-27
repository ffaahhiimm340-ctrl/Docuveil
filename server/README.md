# Relay server

FastAPI relay for the keyed fingerprints from `packages/engine` (`FingerprintSet.toJson()`).
It stores opaque tags only. In-memory today; PostgreSQL (metadata only) goes behind `Store`.

| Method | Path | Body / query |
|---|---|---|
| POST | `/v1/{owner}/fingerprints` | `{device_id, doc, fields: {fieldTag: valueTag}}` |
| GET | `/v1/{owner}/changes?device_id=..&since=N` | entries from the owner's other devices after `N` |

`owner` is a random pairing token (16-128 chars) shared between the owner's devices, not an account.

What the server can learn: message timing and counts, device ids, how many fields a document has.
What it cannot learn: content, field names, values, or whether a tag matches a known file
(tags are HMAC-SHA256 under a key it never sees).

Storage: memory by default. Set `DATABASE_URL` to use SQL, for example PostgreSQL from
`docker-compose.yml`:

```bash
docker compose up -d db
set DATABASE_URL=postgresql+psycopg://docuveil:docuveil_dev@localhost:55432/docuveil
```

The tests run the same cases against memory, SQLite and, when `TEST_DATABASE_URL` is set to the
URL above, PostgreSQL 16 (verified 2026-10-27, all pass).

```bash
py -3.12 -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python -m pytest
.venv\Scripts\python -m uvicorn app.main:app --reload
```
