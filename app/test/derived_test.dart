import 'package:docuveil/data/copy_check.dart';
import 'package:docuveil/data/derived.dart';
import 'package:docuveil/data/sample_data.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil/models/models.dart';
import 'package:docuveil/theme/app_colors.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show DocType, ExtractedDoc;
import 'package:flutter_test/flutter_test.dart';

PaperSource policy(String expiry) {
  final doc = ExtractedDoc(
    id: 'p1',
    type: DocType.insurance,
    fields: {'policy_number': 'POL1', 'expiry_date': expiry},
  );
  return PaperSource(
    id: 'p1',
    title: 'Policy',
    shortTitle: 'Policy',
    copies: [
      CopySnapshot(
        kind: PlaceKind.phone,
        placeName: 'Phone',
        path: 'x',
        sha256: 'a',
        doc: doc,
        original: true,
      ),
    ],
  );
}

void main() {
  final today = DateTime(2026, 11, 4);

  test('renewal dates are read from every date format', () {
    for (final v in ['12/03/2027', '12-03-2027', '12 Mar 2027']) {
      final r = renewalsFrom([policy(v)], today).single;
      expect(r.$1.month, 'MAR');
      expect(r.$1.day, '12');
    }
  });

  test('a date soon is a reminder; a past date is urgent; a far date is neither', () {
    List<AlertItem> alerts(String date) {
      final s = policy(date);
      return alertsFrom([checkPaper(s)], renewalsFrom([s], today))
          .where((a) => a.title.contains('renews'))
          .toList();
    }

    final soon = alerts('20/11/2026').single;
    expect(soon.group, 'soon');
    expect(soon.tone, Tone.bad); // under 30 days
    expect(soon.text, contains('In 16 days'));

    final past = alerts('01/10/2026').single;
    expect(past.group, 'urgent');
    expect(past.text, contains('Expired'));

    expect(alerts('12/03/2030'), isEmpty);
  });

  test('the demo tamper raises the urgent alert, with no hand-written text', () {
    final urgent = SampleData.alerts.where((a) => a.group == 'urgent');
    expect(urgent.single.title, 'Marksheet changed on Google Drive');
    expect(urgent.single.text, contains('went from 8.74 to 9.40'));
    expect(SampleData.urgentCount, 1);
  });

  test('a paper the owner adds shows up in papers, dates and alerts', () async {
    final before = SampleData.papers.length;
    await Vault.add(
      const VaultDoc(
        ExtractedDoc(
          id: 'insurance-added',
          type: DocType.insurance,
          fields: {'name': 'Asha', 'expiry_date': '01/01/2099'},
        ),
        'This device',
        fileName: 'policy.pdf',
      ),
    );
    final papers = SampleData.papers;
    expect(papers.length, before + 1);
    final added = papers.firstWhere((p) => p.id == 'insurance-added');
    expect(added.copies.single.path, 'policy.pdf');
    expect(added.statusText, startsWith('Renews'));
    expect(SampleData.dates.map((d) => d.title), contains('Insurance renews'));
    // One copy only, so it asks for a backup.
    expect(
      SampleData.alerts.map((a) => a.paperId),
      contains('insurance-added'),
    );
  });
}
