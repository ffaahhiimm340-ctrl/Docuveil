import 'dart:convert';
import 'dart:typed_data';

import 'package:docuveil/data/audit_rows.dart';
import 'package:docuveil/data/intake.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show AuditPurpose, DocType;
import 'package:flutter_test/flutter_test.dart';

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  const marksheet = '''
SYNTHETIC UNIVERSITY OF PUNE
Statement of Marks
Name of the Student : Asha Rajesh Verma
Seat No. : S482913
Semester : II
Date of Birth : 14/07/2001''';

  test('a marksheet text becomes a draft; unread fields are flagged', () {
    final d = draftFromText(DocType.marksheet, 'Marksheet_Sem2.pdf', bytes(marksheet), marksheet);
    expect(d.fields['name'], 'Asha Rajesh Verma');
    expect(d.fields['semester'], '2');
    expect(d.fields['seat_number'], 'S482913');
    // The CGPA line is missing from this text: shown empty, asked for.
    expect(d.unread, {'cgpa'});
    expect(d.fields['cgpa'], '');
    expect(d.sha256, hasLength(64));
  });

  test('saving adds the paper to the vault and the audit sees it', () async {
    final before = Vault.docs.value.length;
    final d = draftFromText(DocType.marksheet, 'm.pdf', bytes(marksheet), marksheet);
    d.fields['cgpa'] = '8.74'; // the owner typed the missing value
    final saved = await Intake.save(d);
    expect(Vault.docs.value.length, before + 1);
    expect(saved.doc.fields['cgpa'], '8.74');

    // Its date of birth (14 Jul) disagrees with the demo Aadhaar and PAN
    // (04 Jul); with two marksheets now saying 14 Jul there is a tie on
    // support, so the audit still flags the date as needing a fix.
    final view = buildAuditView(Vault.docs.value, AuditPurpose.panAadhaarLink);
    expect(view.rows.firstWhere((r) => r.field == 'dob').verdict, Verdict.fix);
  });
}
