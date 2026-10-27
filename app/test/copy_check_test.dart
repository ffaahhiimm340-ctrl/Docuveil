import 'package:docuveil/data/copy_check.dart';
import 'package:docuveil/data/sample_data.dart';
import 'package:docuveil/models/models.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show DocType, ExtractedDoc;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marksheet: Drive copy changed CGPA, phone re-scan counts as the same', () {
    final p = SampleData.paperById('marksheet');
    expect(p.status, PaperStatus.changed);
    final cgpa = p.fields.firstWhere((f) => f.isChanged);
    expect(cgpa.label, 'CGPA, Semester 2');
    expect(cgpa.was, '8.74');
    expect(cgpa.value, '9.40');
    final byKind = {for (final c in p.copies) c.kind: c.state};
    expect(byKind[PlaceKind.laptop], CopyState.original);
    expect(byKind[PlaceKind.phone], CopyState.same);
    expect(byKind[PlaceKind.cloud], CopyState.changed);
    expect(p.verdict!.tamper, isTrue);
    expect(p.verdict!.text, contains('Google Drive'));
  });

  test('insurance: amount written as Rs. 5,00,000 is not a change', () {
    final p = SampleData.paperById('insurance');
    expect(p.status, PaperStatus.safe);
    expect(p.statusText, 'Renews 12 Mar');
    expect(p.hasChange, isFalse);
    expect(p.copies.last.state, CopyState.same);
  });

  test('an OCR-like difference is worth a look, not tampering', () {
    ExtractedDoc d(String name) =>
        ExtractedDoc(id: 'x', type: DocType.certificate, fields: {'name': name});
    final p = checkPaper(
      PaperSource(
        id: 'x',
        title: 'X',
        shortTitle: 'X',
        copies: [
          CopySnapshot(
            kind: PlaceKind.laptop,
            placeName: 'Laptop',
            path: 'a',
            sha256: '1',
            doc: d('Asha Verma'),
            original: true,
          ),
          CopySnapshot(
            kind: PlaceKind.phone,
            placeName: 'Phone',
            path: 'b',
            sha256: '2',
            doc: d('Asha Verrna'.replaceAll('rn', 'm').replaceAll('Verma', 'Ver1na')),
          ),
        ],
      ),
    );
    // "Ver1na" vs "Verma" is not just an OCR swap (1/m), so it is a real change.
    expect(p.status, PaperStatus.changed);

    final q = checkPaper(
      PaperSource(
        id: 'y',
        title: 'Y',
        shortTitle: 'Y',
        copies: [
          CopySnapshot(
            kind: PlaceKind.laptop,
            placeName: 'Laptop',
            path: 'a',
            sha256: '1',
            doc: d('Asha Lal'),
            original: true,
          ),
          CopySnapshot(
            kind: PlaceKind.phone,
            placeName: 'Phone',
            path: 'b',
            sha256: '2',
            doc: d('Asha La1'),
          ),
        ],
      ),
    );
    expect(q.status, PaperStatus.look);
    expect(q.copies.last.state, CopyState.review);
    expect(q.verdict!.tamper, isFalse);
  });
}
