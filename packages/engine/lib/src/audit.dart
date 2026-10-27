import 'models.dart';
import 'naming.dart';
import 'normalize.dart';

/// Why the owner is running the audit; only changes the advice text.
enum AuditPurpose { general, panAadhaarLink, passport, exam }

class Mismatch {
  const Mismatch({
    required this.field,
    required this.docA,
    required this.docB,
    required this.valueA,
    required this.valueB,
    required this.level,
    required this.reason,
    required this.advice,
    required this.fix,
  });

  final String field;
  final ExtractedDoc docA;
  final ExtractedDoc docB;
  final String valueA;
  final String valueB;
  final MatchLevel level;
  final String reason;
  final String advice;

  /// The document to correct: whichever of [docA] / [docB] is trusted less.
  final ExtractedDoc fix;
}

class AuditReport {
  const AuditReport(this.mismatches);

  final List<Mismatch> mismatches;

  bool get hasBlocking => mismatches.any((m) => m.level == MatchLevel.blocking);

  /// Differences that need action (everything except harmless variants).
  List<Mismatch> get actionable =>
      mismatches.where((m) => m.level != MatchLevel.equivalent).toList();
}

const _fields = ['name', 'dob', 'gender', 'father_name'];

/// Which document to trust when two disagree, most trusted first. Date of
/// birth is best proven by school or birth records; names by the passport.
/// These orders are a heuristic for the advice text, not a legal ruling.
const _trust = {
  'dob': [
    DocType.certificate, DocType.marksheet, DocType.passport,
    DocType.aadhaar, DocType.pan, DocType.insurance,
  ],
  'default': [
    DocType.passport, DocType.aadhaar, DocType.pan,
    DocType.marksheet, DocType.certificate, DocType.insurance,
  ],
};

String _docName(DocType t) => switch (t) {
  DocType.aadhaar => 'Aadhaar',
  DocType.pan => 'PAN card',
  DocType.marksheet => 'marksheet',
  DocType.insurance => 'insurance policy',
  DocType.certificate => 'certificate',
  DocType.passport => 'passport',
};

bool _sameValue(String field, String x, String y) =>
    (field == 'name' || field == 'father_name')
    ? compareNames(x, y).level == MatchLevel.equivalent
    : normalizeField(field, x) == normalizeField(field, y);

/// (reference, fix): the document to trust and the one to correct. The value
/// most documents agree on wins; the trust order only breaks ties.
(ExtractedDoc, ExtractedDoc) _pickFix(
  String field,
  ExtractedDoc a,
  ExtractedDoc b,
  List<ExtractedDoc> all,
) {
  int support(ExtractedDoc d) => all
      .where(
        (o) =>
            o.fields[field] != null &&
            _sameValue(field, d.fields[field]!, o.fields[field]!),
      )
      .length;
  final sa = support(a), sb = support(b);
  if (sa != sb) return sa > sb ? (a, b) : (b, a);
  final order = _trust[field] ?? _trust['default']!;
  return order.indexOf(a.type) <= order.indexOf(b.type) ? (a, b) : (b, a);
}

String _advice(
  String field,
  ExtractedDoc a,
  ExtractedDoc b,
  MatchLevel level,
  AuditPurpose purpose,
  List<ExtractedDoc> all,
) {
  if (level == MatchLevel.equivalent) {
    return 'No action needed: this is the same value written differently.';
  }
  final (ref, fix) = _pickFix(field, a, b, all);
  final base =
      'Update the ${fieldLabel(field).toLowerCase()} on your '
      '${_docName(fix.type)} to match your ${_docName(ref.type)}.';
  final linking =
      purpose == AuditPurpose.panAadhaarLink &&
      {a.type, b.type}.containsAll({DocType.aadhaar, DocType.pan});
  if (linking && (field == 'dob' || field == 'gender')) {
    return '$base UIDAI requires date of birth and gender to match exactly '
        'for PAN-Aadhaar linking.';
  }
  if (linking && level == MatchLevel.likelyProblem) {
    return '$base UIDAI says a minor name mismatch can be resolved with an '
        'Aadhaar OTP when linking, so you may be able to skip the correction.';
  }
  return base;
}

/// Check that name, date of birth, gender and father's name agree across all
/// the owner's documents, with Indian naming rules for the name fields.
AuditReport audit(
  List<ExtractedDoc> docs, {
  AuditPurpose purpose = AuditPurpose.general,
}) {
  final out = <Mismatch>[];
  for (final field in _fields) {
    final withField = docs.where((d) => (d.fields[field] ?? '').isNotEmpty);
    final list = withField.toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i], b = list[j];
        final x = a.fields[field]!, y = b.fields[field]!;
        if (normalizeField(field, x) == normalizeField(field, y) &&
            (field == 'dob' || field == 'gender' || x.trim() == y.trim())) {
          continue;
        }
        final NameMatch m;
        if (field == 'dob' || field == 'gender') {
          m = normalizeField(field, x) == normalizeField(field, y)
              ? const NameMatch(MatchLevel.equivalent, 'same value')
              : NameMatch(
                  MatchLevel.blocking,
                  '${fieldLabel(field)} must match exactly',
                );
        } else {
          m = compareNames(x, y);
        }
        out.add(
          Mismatch(
            field: field,
            docA: a,
            docB: b,
            valueA: x,
            valueB: y,
            level: m.level,
            reason: m.reason,
            advice: _advice(field, a, b, m.level, purpose, list),
            fix: _pickFix(field, a, b, list).$2,
          ),
        );
      }
    }
  }
  out.sort((p, q) => q.level.index.compareTo(p.level.index));
  return AuditReport(out);
}
