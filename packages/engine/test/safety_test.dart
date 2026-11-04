import 'dart:convert';
import 'dart:typed_data';

import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:test/test.dart';

Uint8List b(String s) => Uint8List.fromList(latin1.encode(s));

void main() {
  group('hidden-script scan', () {
    test('finds scripts and auto-run actions in a PDF', () {
      final f = scanForHiddenScript('a.pdf', b('%PDF-1.7 /OpenAction << /S /JavaScript /JS (x) >>'));
      final text = f.map((x) => x.what).join(' ');
      expect(text, contains('JavaScript'));
      expect(text, contains('runs when opened'));
      expect(f.where((x) => x.what.contains('JavaScript')), hasLength(1));
    });

    test('a plain PDF is clean', () {
      expect(scanForHiddenScript('a.pdf', b('%PDF-1.7 /Type /Page /Font')), isEmpty);
    });

    test('finds a macro in an Office zip, and a disguised program', () {
      final zip = b('PK\x03\x04....word/vbaProject.bin....');
      expect(scanForHiddenScript('a.docm', zip).single.what, contains('macro'));
      expect(scanForHiddenScript('a.docx', b('PK\x03\x04....word/document.xml')), isEmpty);
      expect(
        scanForHiddenScript('marksheet.pdf.exe', b('MZ')).single.what,
        contains('pretends'),
      );
    });
  });

  group('sensitive numbers', () {
    test('finds and masks Aadhaar, PAN and passport-style numbers', () {
      final f = findSensitive('Aadhaar 2345 6789 0123\nPAN ABCPV1234F\nPassport P1234567');
      expect({for (final x in f) x.kind: x.masked}, {
        'Aadhaar-style number': '********0123',
        'PAN-style number': '******234F',
        'Passport-style number': '****4567',
      });
    });

    test('plain text and short numbers are not flagged', () {
      expect(findSensitive('CGPA 8.74, seat S482913, year 2023'), isEmpty);
    });

    test('shared-looking places', () {
      expect(looksShared(r'C:\Users\Asha\Downloads\WhatsApp Documents\a.pdf'), isTrue);
      expect(looksShared('/storage/Shared with family/a.pdf'), isTrue);
      expect(looksShared(r'C:\Users\Asha\Documents\a.pdf'), isFalse);
    });
  });

  group('mass change', () {
    final t0 = DateTime(2026, 11, 4, 10);

    test('a burst of different files trips it', () {
      final d = MassChangeDetector(threshold: 3);
      expect(d.record('a', t0), isFalse);
      expect(d.record('b', t0), isFalse);
      expect(d.record('c', t0), isTrue);
    });

    test('one file saved repeatedly, or slow changes, do not', () {
      final d = MassChangeDetector(threshold: 3);
      for (var i = 0; i < 10; i++) {
        expect(d.record('same', t0), isFalse);
      }
      final slow = MassChangeDetector(threshold: 3);
      for (var i = 0; i < 10; i++) {
        expect(slow.record('f$i', t0.add(Duration(minutes: i))), isFalse);
      }
    });
  });
}
