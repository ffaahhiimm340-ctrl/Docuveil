import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'models.dart';
import 'normalize.dart';

/// unchanged: identical bytes. harmless: bytes differ but no field and
/// (almost) no text changed. review: no tracked field changed but the text
/// differs enough that a person should look. tampered: a tracked field changed.
enum Verdict { unchanged, harmless, review, tampered }

enum ChangeKind { modified, added, removed }

class FieldChange {
  const FieldChange(this.field, this.kind, this.oldValue, this.newValue);

  final String field;
  final ChangeKind kind;
  final String? oldValue;
  final String? newValue;

  String describe() => switch (kind) {
    ChangeKind.modified =>
      '${fieldLabel(field)} changed from $oldValue to $newValue',
    ChangeKind.added => '${fieldLabel(field)} was added: $newValue',
    ChangeKind.removed => '${fieldLabel(field)} was removed (was $oldValue)',
  };
}

class ChangeReport {
  const ChangeReport({
    required this.verdict,
    this.changes = const [],
    this.harmlessNotes = const [],
    this.textSimilarity = 1,
  });

  final Verdict verdict;
  final List<FieldChange> changes;
  final List<String> harmlessNotes;
  final double textSimilarity;

  String summary() => switch (verdict) {
    Verdict.unchanged => 'Unchanged.',
    Verdict.harmless => 'File changed, but no field did (re-save or re-scan).',
    Verdict.review =>
      'No tracked field changed, but the text differs. Please look at it.',
    Verdict.tampered => '${changes.map((c) => c.describe()).join('; ')}.',
  };
}

/// A document at one point in time: its raw-byte hash plus extracted content.
class DocSnapshot {
  const DocSnapshot(this.sha256, this.doc);

  factory DocSnapshot.fromBytes(Uint8List bytes, ExtractedDoc doc) =>
      DocSnapshot(crypto.sha256.convert(bytes).toString(), doc);

  final String sha256;
  final ExtractedDoc doc;
}

/// Dice coefficient over word multisets of the normalised texts.
double textSimilarity(String a, String b) {
  final ta = normalizeText(a).split(' ').where((w) => w.isNotEmpty).toList();
  final tb = normalizeText(b).split(' ').where((w) => w.isNotEmpty).toList();
  if (ta.isEmpty && tb.isEmpty) return 1;
  if (ta.isEmpty || tb.isEmpty) return 0;
  final counts = <String, int>{};
  for (final w in ta) {
    counts[w] = (counts[w] ?? 0) + 1;
  }
  var common = 0;
  for (final w in tb) {
    final n = counts[w] ?? 0;
    if (n > 0) {
      common++;
      counts[w] = n - 1;
    }
  }
  return 2 * common / (ta.length + tb.length);
}

/// Compare a stored baseline with a later version of the same document.
///
/// Pipeline: SHA-256 trigger, then field-by-field comparison of normalised
/// values, then a text-similarity check for edits outside the tracked fields.
ChangeReport compareVersions(
  DocSnapshot baseline,
  DocSnapshot current, {
  double harmlessTextThreshold = 0.9,
}) {
  if (baseline.sha256 == current.sha256) {
    return const ChangeReport(verdict: Verdict.unchanged);
  }
  final a = baseline.doc.fields;
  final b = current.doc.fields;
  final changes = <FieldChange>[];
  final notes = <String>[];
  for (final key in {...a.keys, ...b.keys}) {
    final x = a[key];
    final y = b[key];
    if (x == null) {
      changes.add(FieldChange(key, ChangeKind.added, null, y));
    } else if (y == null) {
      changes.add(FieldChange(key, ChangeKind.removed, x, null));
    } else if (normalizeField(key, x) != normalizeField(key, y)) {
      changes.add(FieldChange(key, ChangeKind.modified, x, y));
    } else if (x != y) {
      notes.add('${fieldLabel(key)} formatting differs');
    }
  }
  if (changes.isNotEmpty) {
    return ChangeReport(
      verdict: Verdict.tampered,
      changes: changes,
      harmlessNotes: notes,
    );
  }
  final sim = textSimilarity(baseline.doc.text, current.doc.text);
  return ChangeReport(
    verdict: sim >= harmlessTextThreshold ? Verdict.harmless : Verdict.review,
    harmlessNotes: notes,
    textSimilarity: sim,
  );
}
