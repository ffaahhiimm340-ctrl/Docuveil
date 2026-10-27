import 'package:docuveil/data/audit_rows.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show AuditPurpose;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('demo papers: DOB needs fixing on the marksheet, surname is worth a look', () {
    final v = buildAuditView(demoDocs(), AuditPurpose.panAadhaarLink);
    final dob = v.rows.firstWhere((r) => r.field == 'dob');
    expect(dob.verdict, Verdict.fix);
    expect(v.papers[dob.oddIndex!], 'Marksheet');
    final name = v.rows.firstWhere((r) => r.field == 'name');
    expect(name.verdict, Verdict.look);
    expect(v.papers[name.oddIndex!], 'Certificate');
    final father = v.rows.firstWhere((r) => r.field == 'father_name');
    expect(father.verdict, Verdict.fine);
  });

  test('SQLite store round-trips documents and seeds the demo vault once', () async {
    final store = await SqliteVaultStore.open(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await Vault.attach(store);
    expect(Vault.docs.value.length, demoDocs().length);
    final loaded = Vault.docs.value.firstWhere((d) => d.doc.id == 'demo-marksheet');
    expect(loaded.doc.fields['dob'], '14 Jul 2001');
    expect(loaded.location, 'Drive');
    await Vault.attach(store); // already filled: no duplicates
    expect((await store.all()).length, demoDocs().length);
    await store.close();
  });
}
