import 'dart:io';

import 'package:docuveil/data/intake.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show DocType;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// Runs in the real desktop app, because PDFium is a native library:
///   flutter test integration_test -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a synthetic PDF is read and its fields extracted', (_) async {
    pdfrxFlutterInitialize();
    final bytes = File('test/fixtures/synthetic_marksheet.pdf').readAsBytesSync();
    final text = await pdfText(bytes);
    expect(text, contains('Asha Rajesh Verma'));

    final d = draftFromText(DocType.marksheet, 'synthetic_marksheet.pdf', bytes, text);
    expect(d.fields['name'], 'Asha Rajesh Verma');
    expect(d.fields['seat_number'], 'S482913');
    expect(d.fields['semester'], '2');
    expect(d.fields['dob'], '14/07/2001');
    expect(d.fields['cgpa'], '8.74');
    expect(d.unread, isEmpty);
  });
}
