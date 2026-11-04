# Docuveil

Research project (~15 weeks, started Oct 2026): a Flutter app (Windows + Android) that keeps personal documents organized and safe, plus one researched engine: **owner-side, field-level checking of personal documents**.

Read `docs/research/text/final-research-plan.txt` first. It is the source of truth for scope, claims and evaluation. Originals (docx/pdf) are in `docs/research/source/`.

## Contributions (in order of strength)
1. Field-level tamper detection: names the changed field with old/new values, separates harmless changes (re-save, re-scan, compression) from tampering. No issuer signature needed.
2. Owner-side cross-document consistency audit (Aadhaar, PAN, marksheet, passport) with Indian naming rules and fix-it advice.
3. Private cross-device sync: HMAC-SHA256 keyed fingerprints relayed by a thin FastAPI server.
4. Availability-aware alerts: per-document score (copies, backup, integrity) sets alert urgency.
5. Synthetic benchmark dataset: tampered, harmless and cross-document-mismatch cases.

Basic layer (build, cite, never claim): search, expiry reminders, YARA/oletools scanning, ransomware decoys, sensitive-data warnings, encrypted storage.

## Stack
Flutter, SQLite (encrypted), ML Kit / Tesseract OCR, a PDF text library, FastAPI + PostgreSQL (metadata only), HMAC-SHA256.

Storage: encrypted SQLite on the device, PostgreSQL on the server (metadata only). Details and tracks: `docs/WORK_SPLIT.md`. Extracted-document JSON: `docs/contracts/fields.md`.

## Layout and ownership
- `app/` Flutter UI (track A). `packages/engine/` pure-Dart engine (track B). `dataset/`, `server/`, `experiments/`, `paper/` (track C).
- One owner per folder. Work on `<track>/<topic>` branches and merge by pull request, never straight to `main`.
- Engine: `cd packages/engine && dart test`. Evaluation: `py -3.12 dataset/generate.py` then `dart run bin/evaluate.dart ../../dataset/generated`. Server: see `server/README.md`.

## Progress
- 2026-10-27: engine v0 (tamper compare, Indian name rules, audit, availability score, keyed fingerprints; 24 tests), dataset generator v0, relay server skeleton (in-memory store). Not done: app wiring, SQLite, OCR, PostgreSQL store, real baselines beyond SHA-256 / Jaro-Winkler.
- 2026-10-27 (later): engine handles Indian amount formats (`10,00,000`) and an OCR-near tier (letter/digit confusions go to `review`, digit-to-digit changes never do). `dataset/generate.py --hard` adds subtle edits and OCR noise; `bin/evaluate.dart` prints per-subtype outcomes. On our hard set: 0 missed tampers, 0 false alarms, ~18% of harmless re-scans sent to review (OCR-like name noise), all from our own generator.
- 2026-10-27 (sync): relay has a SQL store (PostgreSQL via `DATABASE_URL`; tests pass on memory, SQLite and PostgreSQL 16 in Docker on host port 55432, because another local project holds 5432). Engine `detectDivergence` turns relay entries into per-document alerts with urgency. Not done: the Dart HTTP client that calls the relay, key/owner-token pairing between devices.
- 2026-10-27 (relay client): pairing secret (`PairingSecret`, `dv1:` QR code with checksum; the relay's owner token is HMAC-derived from the key) and `RelayClient` (`lib/relay.dart`). `bin/sync_e2e.dart` runs two devices against the real relay + PostgreSQL: 50/50 edits alerted with the right field, 0 false alerts, nothing readable stored, 0 outsider guesses matched. The latency printed (~25 ms) is one push + one pull on localhost, NOT real-world latency, which is about the poll interval plus network time. Found and fixed: field-name tags were identical across documents, letting the relay see shared fields; tags are now bound to the document. The relay still sees owner token, device ids, timing and field count per document. Typed 6-digit pairing (shown in the UI) is not implemented: a short code cannot carry the key without a PAKE; the QR code carries it.
- 2026-10-28 (field extraction): `extractFields` (engine) reads fields from document text per type, with OCR-tolerant labels; `dataset/render_text.py` renders realistic printed layouts with optional OCR noise; `bin/extract_eval.dart` scores it. Field accuracy 100% / 97.6% / 94.2% at 0 / 2 / 5% noise (university and insurer names weakest). End to end, a noisy re-scan of an unchanged document was first called "tampered" 16.8% / 35.2% of the time (2% / 5% noise); after (a) OCR-tolerant labels and (b) the policy that a field unreadable on one copy goes to `review`, not `tampered`, that is 0% / 0.6%, with 20% / 51% sent to review. A one-digit edit followed by a noisy re-scan is still caught 100% / 99.4% (rest went to review). Certificates are not rendered yet; layouts are our own guesses at real ones, so this is not a paper result either.
- 2026-11-04 (real OCR): `dataset/scan_ocr.py` renders synthetic documents as scan-like images and runs RapidOCR (its default model drops spaces); `bin/ocr_eval.dart` scores them. Tuning batch (100 documents, engine fixed while looking at it): 99.4% fields, 0% false tampered, 99% edits tampered. Held-out batch (seed 23, 100 new documents, engine not changed after seeing it; quote this one): 98.9% fields read correctly; unchanged re-scans 91% harmless, 6% review, 3% false tampered (plain SHA-256 alarms on 100%, plain OCR-text diff on 89%); one-digit edits 100% tampered with the field named. Known false-alarm causes, not yet fixed: amount cut short (`Rs.20,00`), label fragment read as a name (`(s) NAIR`), a full-width comma keeping the address on the father's name. Any fix needs a new held-out batch; do not re-quote seed 23 afterwards. Images are rendered with simulated blur and tilt, not printed and photographed, and layouts are our own guesses, so these are still not paper results.
- 2026-11-04 (app build-out, branch `app/real-data`): Add flow reads PDF/text files; papers, alerts and renewals are computed on every screen; fix-steps checklist from the audit; real PIN lock (salted PBKDF2 in secure storage); pairing QR and sync screen; Safety centre with real checks (simple macro/script heuristics, not YARA/oletools); Windows decoy guard, off by default; certificates in `render_text.py`. Windows builds need Visual Studio's ATL component because of `flutter_secure_storage` (add `Microsoft.VisualStudio.Component.VC.ATL`). Not done: database encryption, camera/photo OCR, camera QR scanning, reminder notifications, persistence of ticked steps and safety results, Android testing, clicking through the file picker in the running app, two real devices. Engine changed after the seed-23 batch, so its numbers need a new held-out batch. Paper draft: `paper/draft.md`, with `[TO RUN]` for experiments not done.
- 2026-11-04 (encryption and OCR, branch `app/encryption-ocr`): vault records sealed with AES-256-GCM, key in secure storage, older plain databases migrated and vacuumed. Row count and record sizes stay visible; the key is not derived from the PIN. Photos and picture-only PDFs are read by the OCR built into Windows (the app rebuilds lines from word positions, because Windows splits wide lines and returns pieces out of order) or ML Kit on Android. The Android APK builds but has never run on a device, so ML Kit, secure storage and the file picker are untested there. Camera capture is not implemented.
- Current numbers to quote, Windows OCR, held-out batch (seed 47, 120 documents including certificates, 360 scans, engine frozen at e38e25b before it ran): 95.0% of fields read correctly. Unchanged re-scans with an owner-confirmed baseline: 72.5% harmless, 25.8% review, 1.7% false tampered. With the first scan's OCR trusted as baseline: 76.7% / 20.0% / 3.3%. Plain SHA-256 alarms on 100%, plain OCR-text diff on 49.2%. One-digit edits, confirmed baseline: 96.7% tampered, 3.3% review, 0 missed. Trusting the first OCR: 94.2% / 5.0%, and 0.8% missed (1 of 120), because Windows OCR sometimes drops comma-grouped amounts, so the owner's confirmation step matters. Seeds 23, 41 and 47 are used up: any engine change needs a new seed. Earlier numbers in this file used RapidOCR or simulated noise. Still rendered images with simulated blur and tilt, not printed and photographed documents, so not paper results.
- The 100% scores from `bin/evaluate.dart` are on data from our own generator, so they only show the pipeline works. They are not paper results; the paper needs harder, independently designed cases and OCR noise.

## Hard rules
- Synthetic data only. Never use real Aadhaar/PAN/passport documents.
- Scope: 5 document types (Aadhaar-style ID, PAN-style card, marksheet, insurance policy, certificate), 2 platforms.
- Do not claim content/perceptual hashing, template comparison, two-file comparison, HMAC identifiers, decoy files, criticality alerts, or "first Indian dataset". Say "to our knowledge".
- Every result needs a baseline (plain SHA-256, generic Jaro-Winkler, etc.). See the evaluation plan.
- Verify every reference against the publisher page before it goes into the paper.

## Working across PCs
- Git is the sync channel: pull before starting, commit and push before leaving a machine.
- Clone to `~/Documents/Docuveil` (Windows) or `~/Docuveil` elsewhere. Run `scripts/check-env.ps1` (Windows) or `scripts/check-env.sh` (Linux/macOS) on a new machine to see what is missing.
- Use Python 3.12 for ML/OCR work (`py -3.12 -m venv .venv`); 3.14 may lack wheels. Keep `.venv`, datasets and model weights out of git.
- Install missing tools with `winget` (Windows) after telling the user what and why.
- Machine notes, as of 2026-10-21 (Omkar's main PC): Windows 11, 7.7 GB RAM, no GPU, ~97 GB free. Flutter at `C:\flutter`; Python 3.12 and 3.14; Node 24; Docker present. Tesseract and PostgreSQL not installed. Keep training/experiments CPU-friendly.
