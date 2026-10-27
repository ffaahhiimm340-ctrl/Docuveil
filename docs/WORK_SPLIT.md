# Work split

Three tracks, one owner per folder. Merge through pull requests, never straight to `main`.
Branch names: `<track>/<topic>` (`app/...`, `engine/...`, `data/...`).

| Track | Folders | Work |
|---|---|---|
| A. App (Flutter, local sessions) | `app/` | Wire screens to real data, encrypted SQLite, PIN lock, file picker, OCR (ML Kit / Tesseract), reminders, YARA/oletools scan, ransomware decoys |
| B. Engine (pure Dart) | `packages/engine/` | Field model, tamper detection, Indian name rules, consistency audit, availability score, keyed fingerprints |
| C. Data and server (Python) | `dataset/`, `server/`, `experiments/`, `paper/` | Synthetic documents with labels, FastAPI relay + PostgreSQL, baselines and metrics, paper |

Storage: encrypted SQLite on the device, PostgreSQL on the server (metadata only: keyed tags, never content).

## Contracts

- `docs/contracts/fields.md`: extracted-document JSON and dataset label format.
- Engine API: `compareVersions`, `audit`, `fingerprint`, `availabilityScore` (see `packages/engine/README.md`).
- Server API: `server/README.md`.

## Plan

| Weeks | A | B | C |
|---|---|---|---|
| 1-2 | Local DB | Engine v0 (done) | Dataset generator v0, install Tesseract/PostgreSQL |
| 3-6 | Intake + OCR | Tune tamper checks | Labelled documents, tamper baselines |
| 7-8 | Audit screen wiring | Name rules for more cases | Audit baseline (Jaro-Winkler) |
| 9-10 | Alerts, sync client | Availability score | Keyed sync server |
| 11-12 | Fixes | Fixes | Experiments, 10-15 user ranking study |
| 13-15 | | | Paper and reference checks |
