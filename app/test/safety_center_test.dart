import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:docuveil/data/safety_center.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('docuveil_guard'));
  tearDown(() async {
    await DecoyGuard.disable();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  File decoy(String name) =>
      File(p.join(tmp.path, DecoyGuard.folderName, name));

  test('turning on makes 3 decoys; all well until one is touched', () async {
    await DecoyGuard.enable(tmp, watch: false);
    expect(Directory(p.join(tmp.path, DecoyGuard.folderName)).listSync(), hasLength(3));
    expect(DecoyGuard.verify(), isTrue);
    expect(DecoyGuard.alarm.value, isNull);

    decoy('Tax_Return_scan.txt').writeAsStringSync('ENCRYPTED!!!');
    expect(DecoyGuard.verify(), isFalse);
    expect(DecoyGuard.alarm.value, contains('Tax_Return_scan.txt'));
  });

  test('a deleted decoy trips it', () async {
    await DecoyGuard.enable(tmp, watch: false);
    decoy('Family_IDs_backup.txt').deleteSync();
    expect(DecoyGuard.verify(), isFalse);
    expect(DecoyGuard.alarm.value, contains('deleted'));
  });

  test('turning off removes only its own files', () async {
    final mine = File(p.join(tmp.path, 'my_document.txt'))..writeAsStringSync('keep me');
    await DecoyGuard.enable(tmp, watch: false);
    final extra = File(p.join(tmp.path, DecoyGuard.folderName, 'owner_file.txt'))
      ..writeAsStringSync('keep me too');
    await DecoyGuard.disable();
    expect(mine.existsSync(), isTrue);
    expect(extra.existsSync(), isTrue);
    expect(decoy('Bank_Passwords_old.txt').existsSync(), isFalse);
    expect(DecoyGuard.active.value, isFalse);
  });

  test('a file with a macro in a shared folder gets both warnings', () {
    final r = SafetyLog.check(
      'Offer.docm',
      r'C:\Users\Asha\WhatsApp Documents\Offer.docm',
      Uint8List.fromList(latin1.encode('PK\x03\x04 word/vbaProject.bin')),
      'PAN ABCPV1234F',
    );
    expect(r.scripts.single.what, contains('macro'));
    expect(r.sensitive.single.masked, '******234F');
    expect(r.shared, isTrue);
    expect(r.needsAttention, isTrue);
    expect(SafetyLog.reports.value.first, same(r));
  });

  test('a clean file in a private folder needs nothing', () {
    final r = SafetyLog.check(
      'm.pdf',
      r'C:\Users\Asha\Documents\m.pdf',
      Uint8List.fromList(latin1.encode('%PDF-1.7 /Type /Page')),
      'PAN ABCPV1234F',
    );
    expect(r.scripts, isEmpty);
    expect(r.shared, isFalse);
    expect(r.needsAttention, isFalse);
  });
}
