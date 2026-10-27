import 'package:docuveil_engine/docuveil_engine.dart' hide Verdict;
import 'package:docuveil_engine/docuveil_engine.dart' as engine show Verdict;

import '../models/models.dart';

/// One copy of a paper as the app indexed it: where it is, the hash of its
/// bytes, and the fields read from it.
class CopySnapshot {
  const CopySnapshot({
    required this.kind,
    required this.placeName,
    required this.path,
    required this.sha256,
    required this.doc,
    this.original = false,
  });

  final PlaceKind kind;
  final String placeName;
  final String path;
  final String sha256;
  final ExtractedDoc doc;

  /// The copy saved as the baseline when the paper was first added.
  final bool original;
}

/// Everything known about one paper before the engine has compared copies.
class PaperSource {
  const PaperSource({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.copies,
    this.labels = const {},
    this.status = PaperStatus.safe,
    this.statusText = 'Matches your original',
    this.sealWarnSegment,
  });

  final String id;
  final String title;
  final String shortTitle;
  final List<CopySnapshot> copies;

  /// Field key -> label shown on screen, e.g. `cgpa` -> `CGPA, Semester 2`.
  final Map<String, String> labels;

  /// Status to show when every copy matches (e.g. a renewal is coming up).
  final PaperStatus status;
  final String statusText;
  final int? sealWarnSegment;
}

CopyState _stateFor(engine.Verdict v) => switch (v) {
  engine.Verdict.unchanged || engine.Verdict.harmless => CopyState.same,
  engine.Verdict.review => CopyState.review,
  engine.Verdict.tampered => CopyState.changed,
};

/// Compare every copy with the original and turn the result into a [Paper].
Paper checkPaper(PaperSource s) {
  final original = s.copies.firstWhere(
    (c) => c.original,
    orElse: () => s.copies.first,
  );
  final base = DocSnapshot(original.sha256, original.doc);
  final copies = <PaperCopy>[];
  ChangeReport? worst;
  String? worstPlace;
  for (final c in s.copies) {
    var state = CopyState.original;
    if (!identical(c, original)) {
      final r = compareVersions(base, DocSnapshot(c.sha256, c.doc));
      state = _stateFor(r.verdict);
      if (worst == null || r.verdict.index > worst.verdict.index) {
        worst = r;
        worstPlace = c.placeName;
      }
    }
    copies.add(
      PaperCopy(kind: c.kind, placeName: c.placeName, path: c.path, state: state),
    );
  }

  final flagged = worst != null &&
      (worst.verdict == engine.Verdict.tampered ||
          worst.verdict == engine.Verdict.review);
  final changed = {
    if (flagged)
      for (final ch in worst.changes) ch.field: ch,
  };
  String label(String key) => s.labels[key] ?? fieldLabel(key);
  final keys = original.doc.fields.keys.toList();
  final fields = [
    for (final k in keys)
      changed[k] != null && changed[k]!.kind == ChangeKind.modified
          ? PaperField(label(k), changed[k]!.newValue!, was: changed[k]!.oldValue)
          : PaperField(label(k), original.doc.fields[k]!),
  ];
  final firstChanged = keys.indexWhere(changed.containsKey);

  if (!flagged) {
    return Paper(
      id: s.id,
      title: s.title,
      shortTitle: s.shortTitle,
      status: s.status,
      statusText: s.statusText,
      sealWarnSegment: s.sealWarnSegment,
      fields: fields,
      copies: copies,
    );
  }

  final tamper = worst.verdict == engine.Verdict.tampered;
  final n = worst.changes.length;
  return Paper(
    id: s.id,
    title: s.title,
    shortTitle: s.shortTitle,
    status: tamper ? PaperStatus.changed : PaperStatus.look,
    statusText: tamper
        ? 'Changed: $n detail${n == 1 ? '' : 's'}'
        : 'Worth a look: a copy reads differently',
    brokenSegment: firstChanged < 0 ? 0 : firstChanged % 6,
    sealWarnSegment: tamper ? null : (firstChanged < 0 ? 0 : firstChanged % 6),
    fields: fields,
    copies: copies,
    verdict: tamper
        ? PaperVerdict(
            'This looks like tampering.',
            'The copy on $worstPlace has a different value. Saving, scanning '
                'or shrinking a file never changes a number like this.',
          )
        : PaperVerdict(
            'Probably the scan, but please look.',
            'The copy on $worstPlace differs only by letters a scan often '
                'misreads (like l and 1).',
            tamper: false,
          ),
  );
}
