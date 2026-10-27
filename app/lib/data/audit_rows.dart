import 'package:docuveil_engine/docuveil_engine.dart';

import 'vault.dart';

/// How one detail compares across the owner's papers. Labels follow the
/// research plan: equivalent (fine), likely problem (worth a look), blocking.
enum Verdict { fine, look, fix }

/// One row of the audit table: a detail and what each paper says about it.
class AuditRow {
  const AuditRow(
    this.field,
    this.detail,
    this.values,
    this.verdict, {
    this.oddIndex,
    this.advice,
    this.reason,
  });

  final String field;
  final String detail;

  /// One value per paper in [AuditView.papers]; null means the paper does not show it.
  final List<String?> values;
  final Verdict verdict;

  /// Index of the paper to correct, when [verdict] is not fine.
  final int? oddIndex;
  final String? advice;
  final String? reason;
}

class AuditView {
  const AuditView(this.papers, this.where, this.rows);

  final List<String> papers;
  final List<String> where;
  final List<AuditRow> rows;

  int count(Verdict v) => rows.where((r) => r.verdict == v).length;

  /// Rows that need action, most serious first.
  List<AuditRow> get actionable =>
      rows.where((r) => r.verdict != Verdict.fine).toList()
        ..sort((a, b) => b.verdict.index.compareTo(a.verdict.index));
}

const _labels = {
  'name': 'Name',
  'dob': 'Date of birth',
  'gender': 'Gender',
  'father_name': "Father's name",
};

String docTitle(DocType t) => switch (t) {
  DocType.aadhaar => 'Aadhaar',
  DocType.pan => 'PAN',
  DocType.marksheet => 'Marksheet',
  DocType.insurance => 'Insurance',
  DocType.certificate => 'Certificate',
  DocType.passport => 'Passport',
};

Verdict _verdict(MatchLevel l) => switch (l) {
  MatchLevel.equivalent => Verdict.fine,
  MatchLevel.likelyProblem => Verdict.look,
  MatchLevel.blocking => Verdict.fix,
};

AuditPurpose purposeFor(String label) => switch (label) {
  'PAN and Aadhaar link' => AuditPurpose.panAadhaarLink,
  'Passport' => AuditPurpose.passport,
  'Exam form' => AuditPurpose.exam,
  _ => AuditPurpose.general,
};

/// Run the engine's audit over the vault and shape it for the audit screen.
AuditView buildAuditView(List<VaultDoc> vault, AuditPurpose purpose) {
  final docs = [for (final v in vault) v.doc];
  final report = audit(docs, purpose: purpose);
  final rows = <AuditRow>[];
  for (final field in _labels.keys) {
    final values = [for (final d in docs) d.fields[field]];
    if (values.where((v) => v != null).length < 2) continue;
    final mine = report.mismatches.where((m) => m.field == field).toList()
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    if (mine.isEmpty) {
      rows.add(AuditRow(field, _labels[field]!, values, Verdict.fine));
      continue;
    }
    final worst = mine.first;
    rows.add(
      AuditRow(
        field,
        _labels[field]!,
        values,
        _verdict(worst.level),
        oddIndex: worst.level == MatchLevel.equivalent
            ? null
            : docs.indexWhere((d) => d.id == worst.fix.id),
        advice: worst.advice,
        reason: worst.reason,
      ),
    );
  }
  return AuditView(
    [for (final d in docs) docTitle(d.type)],
    [for (final v in vault) v.location],
    rows,
  );
}
