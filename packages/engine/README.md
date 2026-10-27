# docuveil_engine

Pure Dart. No Flutter, no I/O, so it runs in the app (Windows, Android) and from the command line.

```dart
// 1. Did this document change, and which field?
final report = compareVersions(
  DocSnapshot.fromBytes(oldBytes, oldDoc),
  DocSnapshot.fromBytes(newBytes, newDoc),
);
report.verdict;    // unchanged | harmless | review | tampered
report.summary();  // "Cgpa changed from 8.74 to 9.40."

// 2. Do my documents agree before I apply?
final a = audit([aadhaar, pan, marksheet], purpose: AuditPurpose.panAadhaarLink);
a.actionable;      // mismatches with level, reason and "which document to fix" advice

// 3. Private cross-device alert: only keyed tags leave the device.
final fp = fingerprint(ownerKey, doc);
final tags = changedFieldTags(fp, remoteFp);

// 4. Alert urgency from availability.
alertUrgency(availabilityScore(AvailabilityInput(copies: 1)), tampered: true);
```

Run the tests:

```bash
dart pub get
dart test
```

Known limits (state them in the paper): name rules cover common Indian patterns only; the
availability weights are a first guess until the user-ranking study; OCR noise is not modelled
here (the dataset gives ground-truth fields so OCR error is measured separately).
