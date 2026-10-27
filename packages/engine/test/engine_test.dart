import 'dart:typed_data';

import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:test/test.dart';

ExtractedDoc doc(
  String id,
  DocType type,
  Map<String, String> fields, {
  String text = '',
}) => ExtractedDoc(id: id, type: type, fields: fields, text: text);

Uint8List b(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  group('normalize', () {
    test('dates in common Indian formats agree', () {
      expect(normalizeDate('05/03/1999'), '1999-03-05');
      expect(normalizeDate('5-3-1999'), '1999-03-05');
      expect(normalizeDate('05 Mar 1999'), '1999-03-05');
      expect(normalizeDate('1999-03-05'), '1999-03-05');
    });
    test('numbers ignore trailing zeros', () {
      expect(normalizeNumber('8.740'), normalizeNumber('8.74'));
      expect(normalizeNumber('9.40'), isNot(normalizeNumber('8.74')));
    });
    test('id numbers fold OCR letter/digit confusion but keep digit edits', () {
      expect(normalizeIdNumber('ABCPS 1234 O'), normalizeIdNumber('ABCPS12340'));
      expect(normalizeIdNumber('1234 5678'), isNot(normalizeIdNumber('1234 5679')));
    });
  });

  group('tamper detection', () {
    final base = doc(
      'm1',
      DocType.marksheet,
      {'name': 'Rahul Sharma', 'cgpa': '8.74', 'semester': '2'},
      text: 'University Marksheet Semester 2 Rahul Sharma CGPA 8.74 Pass',
    );

    test('identical bytes are unchanged', () {
      final s = DocSnapshot.fromBytes(b('abc'), base);
      expect(compareVersions(s, s).verdict, Verdict.unchanged);
    });

    test('changed CGPA is tampering, named with old and new value', () {
      final edited = doc(
        'm1',
        DocType.marksheet,
        {'name': 'Rahul Sharma', 'cgpa': '9.40', 'semester': '2'},
        text: 'University Marksheet Semester 2 Rahul Sharma CGPA 9.40 Pass',
      );
      final r = compareVersions(
        DocSnapshot.fromBytes(b('v1'), base),
        DocSnapshot.fromBytes(b('v2'), edited),
      );
      expect(r.verdict, Verdict.tampered);
      expect(r.changes.single.field, 'cgpa');
      expect(r.changes.single.oldValue, '8.74');
      expect(r.changes.single.newValue, '9.40');
      expect(r.summary(), contains('Cgpa changed from 8.74 to 9.40'));
    });

    test('re-scan with formatting noise is harmless', () {
      final rescan = doc(
        'm1',
        DocType.marksheet,
        {'name': 'RAHUL SHARMA', 'cgpa': '8.740', 'semester': '2'},
        text: 'university marksheet semester 2 rahul sharma cgpa 8.740 pass',
      );
      final r = compareVersions(
        DocSnapshot.fromBytes(b('v1'), base),
        DocSnapshot.fromBytes(b('v2'), rescan),
      );
      expect(r.verdict, Verdict.harmless);
      expect(r.harmlessNotes, isNotEmpty);
    });

    test('edit outside tracked fields goes to review', () {
      final edited = doc(
        'm1',
        DocType.marksheet,
        {'name': 'Rahul Sharma', 'cgpa': '8.74', 'semester': '2'},
        text: 'Totally different text with many other words added here',
      );
      final r = compareVersions(
        DocSnapshot.fromBytes(b('v1'), base),
        DocSnapshot.fromBytes(b('v2'), edited),
      );
      expect(r.verdict, Verdict.review);
    });

    test('removed field is reported', () {
      final edited = doc('m1', DocType.marksheet, {'name': 'Rahul Sharma', 'cgpa': '8.74'});
      final r = compareVersions(
        DocSnapshot.fromBytes(b('v1'), base),
        DocSnapshot.fromBytes(b('v2'), edited),
      );
      expect(r.verdict, Verdict.tampered);
      expect(r.changes.single.kind, ChangeKind.removed);
    });
  });

  group('Indian names', () {
    MatchLevel lvl(String x, String y) => compareNames(x, y).level;

    test('equivalent forms', () {
      expect(lvl('Rahul Sharma', 'RAHUL  SHARMA'), MatchLevel.equivalent);
      expect(lvl('Sharma Rahul', 'Rahul Sharma'), MatchLevel.equivalent);
      expect(lvl('R. Sharma', 'Rahul Sharma'), MatchLevel.equivalent);
      expect(lvl('Rahul K. Sharma', 'Rahul Kumar Sharma'), MatchLevel.equivalent);
      expect(lvl('Shri Rahul Sharma', 'Rahul Sharma'), MatchLevel.equivalent);
      expect(lvl("Rahul D'Souza", 'Rahul DSouza'), MatchLevel.equivalent);
    });
    test('likely problems', () {
      expect(lvl('Rahul Kumar Sharma', 'Rahul Sharma'), MatchLevel.likelyProblem);
      expect(lvl('Mohammed Aslam', 'Mohammad Aslam'), MatchLevel.likelyProblem);
      expect(lvl('Priya Patel', 'Priya Shah'), MatchLevel.likelyProblem);
    });
    test('different people block', () {
      expect(lvl('Rahul Sharma', 'Anita Verma'), MatchLevel.blocking);
    });
    test('Kumari is kept as part of a name', () {
      expect(lvl('Sunita Kumari', 'Sunita'), MatchLevel.likelyProblem);
    });
    test('jaro-winkler sanity', () {
      expect(jaroWinkler('martha', 'marhta'), closeTo(0.961, 0.001));
    });
  });

  group('consistency audit', () {
    final aadhaar = doc('a', DocType.aadhaar, {
      'name': 'Rahul Kumar Sharma',
      'dob': '05/03/1999',
      'gender': 'Male',
      'father_name': 'Suresh Sharma',
    });
    final pan = doc('p', DocType.pan, {
      'name': 'RAHUL K SHARMA',
      'dob': '05-03-1999',
      'father_name': 'S Sharma',
    });
    final marks = doc('m', DocType.marksheet, {
      'name': 'Rahul Sharma',
      'dob': '15/03/1999',
    });

    test('equivalent differences need no action', () {
      final r = audit([aadhaar, pan]);
      expect(r.actionable, isEmpty);
      expect(r.mismatches, isNotEmpty);
    });

    test('different DOB blocks and says which document to fix', () {
      final r = audit([aadhaar, marks], purpose: AuditPurpose.panAadhaarLink);
      final dob = r.mismatches.firstWhere((m) => m.field == 'dob');
      expect(dob.level, MatchLevel.blocking);
      expect(dob.advice, contains('Update the dob on your Aadhaar'));
      expect(dob.advice, contains('marksheet'));
      expect(r.hasBlocking, isTrue);
    });

    test('PAN-Aadhaar name mismatch mentions the OTP route', () {
      final p = doc('p2', DocType.pan, {'name': 'Rahul Sharma'});
      final r = audit([aadhaar, p], purpose: AuditPurpose.panAadhaarLink);
      final name = r.mismatches.firstWhere((m) => m.field == 'name');
      expect(name.level, MatchLevel.likelyProblem);
      expect(name.advice, contains('OTP'));
    });
  });

  group('keyed fingerprints', () {
    final key = List<int>.generate(32, (i) => i);
    final otherKey = List<int>.generate(32, (i) => i + 1);
    final d = doc('m1', DocType.marksheet, {'name': 'Rahul', 'cgpa': '8.74'});

    test('same doc, same key is stable and ignores formatting', () {
      final d2 = doc('m1', DocType.marksheet, {'name': 'RAHUL', 'cgpa': '8.740'});
      expect(changedFieldTags(fingerprint(key, d), fingerprint(key, d2)), isEmpty);
    });

    test('a different key gives unlinkable tags', () {
      final a = fingerprint(key, d), c = fingerprint(otherKey, d);
      expect(a.docTag, isNot(c.docTag));
      expect(a.fields.values.toSet().intersection(c.fields.values.toSet()), isEmpty);
    });

    test('changed field is found and mapped back to its name', () {
      final d2 = doc('m1', DocType.marksheet, {'name': 'Rahul', 'cgpa': '9.40'});
      final tags = changedFieldTags(fingerprint(key, d), fingerprint(key, d2));
      expect(namesForTags(key, tags, d.fields.keys), ['cgpa']);
    });

    test('equal values in different fields do not share tags', () {
      final e = doc('x', DocType.pan, {'a_name': 'same', 'b_name': 'same'});
      final f = fingerprint(key, e);
      expect(f.fields.values.toSet().length, 2);
    });

    test('serialised form leaks no plain field names or values', () {
      final json = fingerprint(key, d).toJson().toString();
      expect(json.contains('cgpa'), isFalse);
      expect(json.contains('8.74'), isFalse);
    });
  });

  group('availability', () {
    test('fragile document scores low, well protected scores high', () {
      final low = availabilityScore(const AvailabilityInput(copies: 1));
      final high = availabilityScore(
        const AvailabilityInput(copies: 3, daysSinceBackup: 1),
      );
      expect(low, lessThan(50));
      expect(high, greaterThan(90));
    });
    test('tampered + fragile is immediate, tampered + protected is low', () {
      expect(alertUrgency(20, tampered: true), Urgency.immediate);
      expect(alertUrgency(95, tampered: true), Urgency.low);
      expect(alertUrgency(10, tampered: false), Urgency.low);
    });
    test('failed integrity lowers the score', () {
      const ok = AvailabilityInput(copies: 2, daysSinceBackup: 5);
      const bad = AvailabilityInput(copies: 2, daysSinceBackup: 5, integrityOk: false);
      expect(availabilityScore(bad), lessThan(availabilityScore(ok)));
    });
  });
}
