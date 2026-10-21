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
