# Contract: extracted document JSON

Produced by app OCR, written as ground truth by `dataset/`, consumed by `packages/engine`.
Dart model: `ExtractedDoc` in `packages/engine/lib/src/models.dart`.

```json
{
  "id": "p007-aadhaar",
  "doc_type": "aadhaar",
  "fields": { "name": "Rahul Kumar Sharma", "dob": "05/03/1999", "gender": "Male" },
  "text": "full text of the document"
}
```

- `doc_type`: `aadhaar | pan | marksheet | insurance | certificate | passport`.
- Field keys are lower_snake_case. Keys ending `_date` and `dob` are dates (day-first), keys ending `_number` are ID numbers, `gender` is gender; everything else is text or a number.
- Shared keys across documents: `name`, `dob`, `gender`, `father_name`. The consistency audit only compares these.
- Values are kept exactly as printed. Normalisation happens in the engine, never in the producer.
- All data is synthetic. Never put real Aadhaar, PAN or passport details in this format.

## Dataset labels (written by `dataset/`)

Each case file adds a `label` block next to the documents:

```json
{ "kind": "tamper", "baseline": {...}, "current": {...},
  "label": { "verdict": "tampered", "changed_fields": { "cgpa": ["8.74", "9.40"] } } }
```

`kind` is `tamper`, `harmless` or `audit`. For `harmless`, `label.transform` names the change
(`resave`, `rescan_noise`, `case_change`, `date_format`). For `audit`, `label.mismatches` lists
`{field, docs, level}` with `level` one of `equivalent | likelyProblem | blocking`.
