import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:docuveil/data/intake.dart';
import 'package:docuveil/data/pin_lock.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil/data/vault_cipher.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show DocType, ExtractedDoc;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const secretName = 'Asha Rajesh Verma';
const secretNumber = '2345 6789 0123';

VaultDoc paper() => const VaultDoc(
  ExtractedDoc(
    id: 'aadhaar-abc',
    type: DocType.aadhaar,
    fields: {'name': secretName, 'id_number': secretNumber},
    text: 'GOVERNMENT OF INDIA $secretName',
  ),
  'This device',
  fileName: 'my_aadhaar.pdf',
);


void main() {
  sqfliteFfiInit();
  late Directory tmp;
  late String path;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('docuveil_vault');
    path = p.join(tmp.path, 'vault.db');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<SqliteVaultStore> open(VaultCipher c) =>
      SqliteVaultStore.open(path, cipher: c, factory: databaseFactoryFfi);

  bool fileHas(String text) =>
      latin1.decode(File(path).readAsBytesSync(), allowInvalid: true).contains(text);

  test('records round-trip, and the file on disk shows nothing readable', () async {
    final c = VaultCipher.random();
    final s = await open(c);
    await s.put(paper());
    await s.close();
    for (final plain in [secretName, secretNumber, 'my_aadhaar', 'aadhaar', 'GOVERNMENT']) {
      expect(fileHas(plain), isFalse, reason: plain);
    }
    final again = await open(c);
    final got = (await again.all()).single;
    expect(got.doc.fields['name'], secretName);
    expect(got.doc.type, DocType.aadhaar);
    expect(got.fileName, 'my_aadhaar.pdf');
    await again.close();
  });

  test('the wrong key cannot read it, and the failure is not silent', () async {
    final s = await open(VaultCipher.random());
    await s.put(paper());
    await s.close();
    final other = await open(VaultCipher.random());
    expect(other.all(), throwsA(isA<SecretBoxAuthenticationError>()));
    await other.close();
  });

  test('a record altered or moved to another row fails to open', () async {
    final c = VaultCipher.random();
    final sealed = await c.seal('hello', 'row-a');
    expect(await c.open(sealed, 'row-a'), 'hello');
    expect(c.open(sealed, 'row-b'), throwsA(isA<SecretBoxAuthenticationError>()));
    final bytes = base64.decode(sealed);
    bytes[bytes.length ~/ 2] ^= 1;
    expect(c.open(base64.encode(bytes), 'row-a'), throwsA(isA<SecretBoxAuthenticationError>()));
  });

  test('sealing the same text twice gives different results', () async {
    final c = VaultCipher.random();
    expect(await c.seal('same', 'r'), isNot(await c.seal('same', 'r')));
  });

  test('an old plain database is encrypted and its plain text is gone', () async {
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE docs (id TEXT PRIMARY KEY, doc_type TEXT NOT NULL, location TEXT NOT NULL, fields TEXT NOT NULL, text TEXT NOT NULL, file_name TEXT)',
        ),
      ),
    );
    await old.insert('docs', {
      'id': 'aadhaar-abc',
      'doc_type': 'aadhaar',
      'location': 'This device',
      'fields': jsonEncode({'name': secretName}),
      'text': 'GOVERNMENT OF INDIA',
      'file_name': 'my_aadhaar.pdf',
    });
    await old.close();
    expect(fileHas(secretName), isTrue); // really was plain

    final s = await open(VaultCipher.random());
    final got = (await s.all()).single;
    expect(got.doc.fields['name'], secretName);
    expect(got.fileName, 'my_aadhaar.pdf');
    await s.close();
    expect(fileHas(secretName), isFalse);
    expect(fileHas('GOVERNMENT'), isFalse);
  });

  test('the key is created once and kept in the store', () async {
    final store = MemoryPinStore();
    final a = await VaultCipher.loadOrCreate(store);
    final b = await VaultCipher.loadOrCreate(store);
    expect(await b.open(await a.seal('x', 'r'), 'r'), 'x');
    expect(await store.read('docuveil_vault_key'), isNotNull);
  });

  group('reading files', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    TestWidgetsFlutterBinding.ensureInitialized();

    test('a text file needs no OCR', () async {
      final d = await Intake.readBytes(
        DocType.marksheet,
        'm.txt',
        'txt',
        Uint8List.fromList(utf8.encode('Name : Asha Verma')),
        null,
      );
      expect(d.fields['name'], 'Asha Verma');
      expect(d.fromScan, isFalse);
    });

    test('with no OCR on this device, a photo asks for typing', () async {
      final d = await Intake.readBytes(DocType.marksheet, 'm.jpg', 'jpg', bytes, null);
      expect(d.problem, contains('type the details'));
      expect(d.fields['name'], '');
    });
  });
}
