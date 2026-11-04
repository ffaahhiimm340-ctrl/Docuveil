import 'dart:convert';
import 'dart:io';

import 'package:docuveil/data/intake.dart';
import 'package:docuveil/data/ocr_service.dart';
import 'package:docuveil/data/pin_lock.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil/data/vault_cipher.dart';
import 'package:docuveil_engine/docuveil_engine.dart'
    show DocType, ExtractedDoc, normalizeField;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'fixtures.dart';

/// Runs on a real device, with its real OCR, PDF engine, secure storage and
/// database. Synthetic data only.
///   flutter test integration_test/device_test.dart -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    pdfrxFlutterInitialize();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      ffi.sqfliteFfiInit();
      databaseFactory = ffi.databaseFactoryFfi;
    }
    debugPrint('Testing on: $defaultTargetPlatform');
  });

  testWidgets('this platform has an OCR engine', (_) async {
    expect(OcrEngine.forPlatform(), isNotNull);
  });

  testWidgets('a PDF with a text layer is read', (_) async {
    final bytes = base64.decode(textPdf);
    final d = await Intake.readBytes(DocType.marksheet, 'a.pdf', 'pdf', bytes, OcrEngine.forPlatform());
    expect(d.fromScan, isFalse);
    expect(d.fields['seat_number'], 'S482913');
    expect(d.fields['cgpa'], '8.74');
    expect(d.unread, isEmpty);
  });

  testWidgets('a scanned photo is read by OCR', (_) async {
    final d = await Intake.readBytes(
      DocType.marksheet,
      'scan.jpg',
      'jpg',
      base64.decode(scanJpg),
      OcrEngine.forPlatform(),
    );
    debugPrint('OCR text:\n${d.text}');
    expect(d.problem, isNull);
    expect(d.fromScan, isTrue);
    expect(normalizeField('name', d.fields['name'] ?? ''), normalizeField('name', 'Asha Rajesh Verma'));
    expect(d.fields['seat_number'], 'S482913');
    expect(d.fields['cgpa'], '8.74');
  });

  testWidgets('a PDF that is only a picture falls back to OCR', (_) async {
    final bytes = base64.decode(scannedPdf);
    expect((await pdfText(bytes)).trim(), isEmpty);
    final d = await Intake.readBytes(DocType.marksheet, 's.pdf', 'pdf', bytes, OcrEngine.forPlatform());
    debugPrint('OCR text:\n${d.text}');
    expect(d.fromScan, isTrue);
    expect(d.fields['seat_number'], 'S482913');
    expect(d.fields['cgpa'], '8.74');
  });

  testWidgets('temporary copies of a scan are deleted', (_) async {
    final tmp = await getTemporaryDirectory();
    int scans() => tmp
        .listSync()
        .where((e) => p.basename(e.path).startsWith('docuveil_scan'))
        .length;
    final before = scans();
    await ocrBytes(OcrEngine.forPlatform()!, base64.decode(scanJpg), 'jpg');
    expect(scans(), before);
  });

  testWidgets('secure storage keeps a value', (_) async {
    final store = SecurePinStore();
    await store.write('docuveil_test_value', 'stored');
    expect(await store.read('docuveil_test_value'), 'stored');
    final pin = await VaultCipher.loadOrCreate(store);
    final again = await VaultCipher.loadOrCreate(store);
    expect(await again.open(await pin.seal('x', 'r'), 'r'), 'x');
  });

  testWidgets('the encrypted database works, and its file shows no plain text', (_) async {
    final base = await getTemporaryDirectory();
    final dir = await base.createTemp('docuveil_it');
    try {
      final path = p.join(dir.path, 'vault.db');
      final key = VaultCipher.random();
      final s = await SqliteVaultStore.open(path, cipher: key);
      await s.put(
        const VaultDoc(
          ExtractedDoc(
            id: 'aadhaar-x',
            type: DocType.aadhaar,
            fields: {'name': 'Asha Rajesh Verma'},
          ),
          'Phone',
        ),
      );
      await s.close();
      final raw = latin1.decode(File(path).readAsBytesSync(), allowInvalid: true);
      expect(raw.contains('Asha'), isFalse);
      final again = await SqliteVaultStore.open(path, cipher: key);
      expect((await again.all()).single.doc.fields['name'], 'Asha Rajesh Verma');
      await again.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
