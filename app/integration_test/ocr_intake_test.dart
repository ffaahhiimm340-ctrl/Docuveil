import 'dart:io';

import 'package:docuveil/data/intake.dart';
import 'package:docuveil/data/ocr_service.dart';
import 'package:docuveil/data/pin_lock.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil/data/vault_cipher.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show DocType, normalizeField;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs in the real Windows app, with the real OCR and secure storage:
///   flutter test integration_test/ocr_intake_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a synthetic scan (photo) is read by Windows OCR', (_) async {
    final bytes = File('test/fixtures/synthetic_marksheet_scan.jpg').readAsBytesSync();
    final d = await Intake.readBytes(
      DocType.marksheet,
      'scan.jpg',
      'jpg',
      bytes,
      OcrEngine.forPlatform(),
    );
    expect(d.problem, isNull);
    expect(d.fromScan, isTrue);
    expect(normalizeField('name', d.fields['name']!), normalizeField('name', 'Asha Rajesh Verma'));
    expect(d.fields['seat_number'], 'S482913');
    expect(d.fields['cgpa'], '8.74');
  });

  testWidgets('a PDF that is only a picture falls back to OCR', (_) async {
    pdfrxFlutterInitialize();
    final bytes = File('test/fixtures/synthetic_marksheet_scanned.pdf').readAsBytesSync();
    expect((await pdfText(bytes)).trim(), isEmpty); // really has no text layer
    final d = await Intake.readBytes(
      DocType.marksheet,
      'scanned.pdf',
      'pdf',
      bytes,
      OcrEngine.forPlatform(),
    );
    expect(d.fromScan, isTrue);
    expect(d.fields['seat_number'], 'S482913');
    expect(d.fields['cgpa'], '8.74');
  });

  testWidgets('temporary copies of a scan are deleted', (_) async {
    final tmp = await getTemporaryDirectory();
    List<String> scans() => tmp
        .listSync()
        .map((e) => p.basename(e.path))
        .where((n) => n.startsWith('docuveil_scan'))
        .toList();
    final before = scans().length;
    await ocrBytes(
      OcrEngine.forPlatform()!,
      File('test/fixtures/synthetic_marksheet_scan.jpg').readAsBytesSync(),
      'jpg',
    );
    expect(scans().length, before);
  });

  testWidgets('the vault key survives in real secure storage', (_) async {
    expect(defaultTargetPlatform, TargetPlatform.windows);
    final store = SecurePinStore();
    await store.write('docuveil_test_value', 'stored');
    expect(await store.read('docuveil_test_value'), 'stored');

    // A real encrypted database file, read back after closing it.
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('docuveil_it');
    try {
      final path = p.join(dir.path, 'vault.db');
      final key = VaultCipher.random();
      final s = await SqliteVaultStore.open(path, cipher: key, factory: databaseFactoryFfi);
      await Vault.attach(s);
      await s.close();
      expect(File(path).existsSync(), isTrue);
      final again = await SqliteVaultStore.open(path, cipher: key, factory: databaseFactoryFfi);
      expect(await again.all(), isNotEmpty);
      await again.close();
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
