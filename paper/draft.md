# Owner-Side Field-Level Integrity and Consistency Checking for Personal Documents

> **FIRST DRAFT. NOT READY TO SUBMIT.**
>
> - Written with an AI assistant. Rewrite it in your own voice, and follow the target venue's rule on disclosing AI-generated content (IEEE requires disclosure).
> - Every number marked PRELIMINARY comes from a synthetic set built by the same people who built the system, with simulated scans. Replace them with the final experiment before submitting.
> - `[TO RUN]` marks experiments that have not been done. Do not fill these in by estimate.
> - `[VERIFY]` marks a claim or reference to check. Bracketed numbers follow the reference list in `docs/research/text/final-research-plan.txt`. Check every reference on its publisher's page, and run the manual Google Scholar pass before relying on "to our knowledge".
> - Author names, affiliations and the venue are still to be decided.

## Abstract

People keep copies of important documents on several devices and cloud accounts, yet they have no simple way to learn whether a copy has been altered, or whether their documents agree with each other before they apply for a service. Existing integrity methods depend on the issuer, judge a single image without an original, or serve a verifier such as a lender. We present an owner-side system in which an individual's app records a baseline of each document's fields when it is first added, then reports which named field later changed, with old and new values, and separates harmless changes such as re-scans from likely tampering. The same field extraction drives a pre-application audit that compares name, date of birth and gender across the owner's documents using common Indian naming conventions and advises which document to correct. Alerts are coordinated across the owner's devices with keyed fingerprints relayed by a server that cannot read documents. On a synthetic benchmark using rendered, scan-like images and a real OCR engine, [PRELIMINARY: 95.0% of fields were read correctly; with an owner-confirmed baseline, 1.7% of unchanged re-scans were wrongly flagged as tampered, against 100% for plain SHA-256, and none of 120 one-digit edits went unflagged]. [TO RUN: final results and the user ranking study.]

## I. Introduction

An Indian student or job applicant may hold an Aadhaar card, a PAN card, marksheets, certificates and insurance papers as files spread across a phone, a laptop and a cloud drive. Two practical problems follow. First, a copy may change, through tampering or an error, without the owner noticing. Second, small differences between documents, such as an initial on one and a full name on another, can stop an application: name, gender or date-of-birth mismatches are a known cause of failed PAN-Aadhaar linking, where UIDAI states that date of birth and gender must match exactly while a minor name mismatch can be resolved with an Aadhaar OTP [40].

Existing document-integrity methods rely on the issuer: a signature with change rules [35], a printed integrity code [5, 6], or registration with a government locker [26]. Others judge a single image without an original [9, 10], or compare document versions on behalf of a verifier, through manual comparison tools [27], lender fraud engines [43] or document-image change-detection research [42]. Identity-consistency checks exist, but they run for banks and verifiers, not for the person who holds the documents [28-33, 39].

To our knowledge, no system lets an individual, without issuer cooperation, automatically learn which named field of their own document changed and whether the change was likely harmless, coordinate such alerts across their devices without revealing documents to a server, and audit their own documents for cross-document mismatches before applying for a service. [VERIFY after the Scholar pass.]

Our contributions are:

1. Owner-side field-level tamper detection with a harmless/review/tampered verdict, requiring no issuer signature or code.
2. An owner-side cross-document consistency audit with Indian naming rules and advice on which document to correct.
3. A keyed-fingerprint protocol for coordinating alerts across one person's devices, with a threat model of what the relay learns.
4. Availability-aware alert urgency computed per document for one person. [Depends on the ranking study.]
5. A synthetic benchmark with tampered and harmless pairs and cross-document mismatch sets.

The mechanisms underneath, such as content hashing, HMAC identifiers, template comparison and criticality-based alerting, are established; we cite and reuse them. Our contribution is their owner-side combination and evaluation.

## II. Related Work

*(The plan's draft related-work text is in `docs/research/text/final-research-plan.txt`. Rewrite it in your own words here; do not paste it. Keep its structure: personal information management [1-4]; issuer-based integrity [5, 6, 26, 35]; reference-based and forensic tamper detection [7-12, 27, 42, 43]; cross-device integrity and private identifiers [13-15, 36]; alert prioritization [24, 25, 37, 38]; cross-document identity consistency [28-33, 39-41]; malicious documents and ransomware [16-23], as a basic layer only.)*

Caution from the prior-art check: [28] is a low-tier journal with doubtful references, so cite it as related work without relying on its numbers. Do not cite the Resistant AI indicator guide, which is marked confidential; cite only the public page [43].

## III. System Overview

The system is a Flutter application for Windows and Android, with a thin relay server. Everything that reads document content runs on the device.

- **Intake.** A file's text comes from its PDF text layer or OCR. A rule-based extractor reads the fields for each document type, tolerating common OCR confusions. The owner confirms or corrects the fields, which become the baseline.
- **Tamper check.** Later copies are compared with the baseline (Section IV).
- **Consistency audit.** The owner's documents are compared with each other (Section V).
- **Sync.** Devices exchange keyed fingerprints through the relay (Section VI).
- **Basic layer (cited, not claimed).** Search, renewal reminders, a static check for macros and scripts, decoy-based ransomware warnings on Windows, and warnings for ID numbers in shared-looking folders.

[TO DO: architecture figure. Note honestly at submission time which parts are implemented and tested. Vault records are encrypted with a key in secure storage, not as a whole database. Camera capture is not built, and nothing has run on an Android device yet.]

## IV. Field-Level Tamper Detection

Given a baseline and a later copy, the engine proceeds as follows:

1. **Trigger.** Identical SHA-256 hashes mean the copy is unchanged.
2. **Field comparison.** Each field is normalized by its kind: dates to a canonical form read day-first, numbers and Indian-format amounts (`10,00,000`) to digits, ID numbers with look-alike letters folded to digits, and text with case, punctuation and spacing removed.
3. **Verdict.** A field read on both copies whose values differ in a way OCR cannot explain gives *tampered*. A difference limited to characters OCR commonly confuses, or a field unreadable on one copy, gives *review*. A digit changing to a different digit is never excused as OCR. If no field differs, the remaining text is compared; any differing number outside the tracked fields, or low text similarity, gives *review*, and otherwise the verdict is *harmless*.

The report names each changed field with its old and new values, for example: "CGPA changed from 8.74 to 9.40."

The *review* class exists because evaluation showed it was needed. Treating an unreadable field as removed, and so as tampering, labelled 16.8% and 35.2% of unchanged documents as tampered at 2% and 5% simulated character noise [PRELIMINARY]. Separately, an edit to a field the extractor missed could pass as harmless until differing numbers outside tracked fields were sent to review. The trade-off is more requests for the owner to look.

## V. Cross-Document Consistency Audit

Name, date of birth, gender and father's name are compared across all pairs of the owner's documents. Dates and gender must match after normalization; a difference is *blocking*. Names are classified as:

- *equivalent*: case or punctuation, name order, or an initial standing for a full name;
- *likely problem*: a missing name part, a spelling or transliteration variant, or a differing surname, as with a maiden and married name;
- *blocking*: different names.

Advice names the document to correct. The value most documents agree on is preferred, and a trust order per field breaks ties. For PAN-Aadhaar linking, the advice reflects UIDAI's rule [40]. The trust order is a heuristic for advice, not a legal ruling.

## VI. Private Cross-Device Coordination

Devices share a 32-byte key through a QR code. For each document they send the relay HMAC-SHA256 tags: a document tag, and for each field a field tag bound to the document and a value tag over the normalized value. The relay's mailbox name is itself derived from the key. A device compares its tags with those of the owner's other devices, and maps differing tags back to field names locally. Keyed tags address the confirmation-of-file attack that plain hashes allow [13-15].

**Threat model.** The relay does not learn content, field names or values, and an outsider holding the same document cannot match a tag without the key. It does learn the mailbox name, random device IDs, message timing and counts, and the number of fields per document. Evaluation exposed one leak we then fixed: field-name tags were originally identical across documents, which revealed which documents shared fields.

**Limitations.** An alert says copies disagree, not which is correct. Papers are matched across devices by type and their own number, so an edit to that number itself is not reported by sync.

## VII. Availability-Aware Alerts

Each document gets a score from its number of copies, backup recency and integrity status, and the score sets tamper-alert urgency: immediate, batched or low. The weights (0.4, 0.3, 0.3) are a starting guess. [TO RUN: tune and validate against rankings from the user study.]

## VIII. Evaluation

**Data.** All documents are synthetic; no real identity documents were used. [TO DO: final dataset description, including size. The plan calls for 150-200 base documents and about 50 synthetic people with 4-5 documents each.]

**Scanned images.** Documents are rendered in four fonts with tilt, blur, reduced resolution and JPEG compression, and read with the OCR built into Windows, which the Windows app uses. [TO RUN: printed and photographed documents across several phones, which is the most important remaining experiment; ML Kit on Android.]

**Method.** Each batch is used once. The engine was frozen before the batch below ran; earlier batches were used for development, and each exposed problems the previous one had not.

### Results on a held-out batch [PRELIMINARY]

120 documents and 360 scans, not seen during development. The app asks the owner to correct the fields of the first scan, so a *confirmed* baseline is the intended use; *as read* trusts the first scan's OCR, as a careless owner would.

| Unchanged document, scanned twice | Harmless | Review | False "tampered" |
|---|---|---|---|
| Docuveil, confirmed baseline | 72.5% | 25.8% | 1.7% |
| Docuveil, baseline as read | 76.7% | 20.0% | 3.3% |
| Plain SHA-256 | - | - | 100% |
| Plain OCR-text diff | - | - | 49.2% |

| One digit edited, then scanned | Tampered | Review | Missed |
|---|---|---|---|
| Docuveil, confirmed baseline | 96.7% | 3.3% | 0% |
| Docuveil, baseline as read | 94.2% | 5.0% | 0.8% (1 of 120) |

Fields read correctly: 95.0%; the weakest was the insured amount at 70.0%. With a confirmed baseline, the edited field was named in 97.5% of edit cases. The single miss occurred because the OCR dropped a comma-grouped amount on both copies, so the field was never compared; this is why the owner's confirmation step matters. About a quarter of harmless re-scans ask the owner to look, which is the main cost of the design and needs testing with users. [TO RUN: confidence intervals; with 120 documents these are wide.]

Development also showed that small samples mislead: a batch on the same engine with a different OCR moved false alarms from 3% to 13.3%, because Windows OCR returned the pieces of wide lines out of order. Rebuilding lines from word positions fixed most of that.

### Consistency audit [PRELIMINARY]

On generated cases, a generic baseline (Jaro-Winkler at 0.9 for names, exact match for dates) gave F1 0.33, with precision 22.5% and recall 61.6%. The engine scored 1.00, but its rules and the cases were written by the same authors, so **this score is not meaningful evidence**. [TO RUN: mismatch cases designed by someone who has not seen the rules; accuracy per case type: initials, order swap, punctuation, maiden/married, transliteration.]

### Other experiments

| Experiment | Status |
|---|---|
| Sync: 50 edits across two simulated devices through the real relay and PostgreSQL | All alerted with the correct field, no false alerts [PRELIMINARY] |
| Privacy: inspect stored rows; outsider guesses against tags | No plain field names or values stored; no guess matched [PRELIMINARY] |
| Sync latency between real devices | [TO RUN] (the 25 ms measured on one machine is not a real-world figure) |
| Availability score vs rankings from 10-15 users (Spearman, against random ranking) | [TO RUN] |
| Confidence intervals for all results | [TO RUN] |

## IX. Limitations

- Five document types and two platforms; Android sandboxing limits what can be monitored.
- Synthetic data only, and real-world OCR noise may be worse. Layouts are approximations of real documents.
- Rule-based extraction depends on those layouts.
- Name rules cover common Indian patterns, not every regional convention or script.
- The owner must confirm the first baseline: a document already altered when added would be trusted.
- The relay sees timing and message counts.
- Decoy-based ransomware detection can be bypassed by decoy-aware ransomware [23], and the script check is a heuristic, not an antivirus.

## X. Conclusion

[Write last, from the final results.]

## References

Copy the verified list from `docs/research/text/final-research-plan.txt`, keep only what is cited, and format it in IEEE style. Check every entry on its publisher's page. Label vendor documentation as such.
