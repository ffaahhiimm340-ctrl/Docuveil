import 'dart:io';
import 'dart:typed_data';

import 'package:docuveil/data/audit_rows.dart';
import 'package:docuveil/data/reminders.dart';
import 'package:docuveil/data/safety_center.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil/data/vault_cipher.dart';
import 'package:docuveil_engine/docuveil_engine.dart' show DocType, ExtractedDoc;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 11, 4, 12);

  group('reminder plan', () {
    test('one per chosen lead time, at 9 am, only in the future', () {
      final plan = planReminders(
        [('Policy renews', DateTime(2026, 12, 20))],
        [30, 7, 1],
        now,
      );
      expect(plan.map((r) => r.at), [
        DateTime(2026, 11, 20, 9),
        DateTime(2026, 12, 13, 9),
        DateTime(2026, 12, 19, 9),
      ]);
      expect(plan.last.body, contains('tomorrow'));
      expect(plan.map((r) => r.id).toSet(), hasLength(3));
    });

    test('dates already passed are skipped', () {
      expect(planReminders([('P', DateTime(2026, 11, 10))], [30, 7], now), isEmpty);
      expect(planReminders([('P', DateTime(2026, 10, 1))], [1], now), isEmpty);
    });

    test('turned-off lead times give nothing', () {
      expect(planReminders([('P', DateTime(2027, 1, 1))], const [], now), isEmpty);
    });

    test('reminder text has no personal details', () {
      final r = planReminders([('Insurance renews', DateTime(2027, 1, 1))], [30], now).single;
      expect(r.title, 'Insurance renews');
      expect(r.body, 'Due in 30 days. Open Docuveil to see it.');
    });

    test('weekly reminder lands on the next Monday at 9', () {
      final next = nextWeekly(now); // 4 Nov 2026 is a Wednesday
      expect(next, DateTime(2026, 11, 9, 9));
      expect(nextWeekly(DateTime(2026, 11, 9, 8)), DateTime(2026, 11, 9, 9));
      expect(nextWeekly(DateTime(2026, 11, 9, 10)), DateTime(2026, 11, 16, 9));
    });
  });

  group('weekly fix-steps count', () {
    VaultDoc paper(String id, DocType t, String dob) => VaultDoc(
      ExtractedDoc(id: id, type: t, fields: {'name': 'Asha Verma', 'dob': dob}),
      'Phone',
    );

    test('sample papers never count, even though they disagree', () {
      expect(fixStepsLeft(demoDocs(), 'Passport', {}), 0);
    });

    test('the owner\'s own mismatch counts until it is ticked', () {
      final mine = [
        paper('a', DocType.aadhaar, '04/07/2001'),
        paper('b', DocType.marksheet, '14/07/2001'),
      ];
      expect(fixStepsLeft(mine, 'Passport', {}), 1);
      final view = buildAuditView(mine, purposeFor('Passport'));
      expect(fixStepsLeft(mine, 'Passport', {stepKey(view.actionable.single)}), 0);
    });
  });

  group('state survives a restart, encrypted', () {
    late Directory tmp;
    late String path;
    late VaultCipher key;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('docuveil_state');
      path = p.join(tmp.path, 'vault.db');
      key = VaultCipher.random();
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<SqliteVaultStore> open() =>
        SqliteVaultStore.open(path, cipher: key, factory: databaseFactoryFfi);

    test('ticks, safety results and choices come back, and are not readable on disk', () async {
      var s = await open();
      await Vault.attach(s);

      doneSteps
        ..clear()
        ..add('dob|STEP-MARKER');
      await saveDoneSteps();
      ReminderPrefs.days1 = true;
      ReminderPrefs.days30 = false;
      await ReminderPrefs.save();
      SafetyLog.reports.value = const [];
      SafetyLog.check(
        'Offer.docm',
        '/Shared/Offer.docm',
        Uint8List.fromList('PK\x03\x04 word/vbaProject.bin'.codeUnits),
        'PAN ABCPV1234F',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await s.close();

      final raw = String.fromCharCodes(File(path).readAsBytesSync());
      for (final plain in ['STEP-MARKER', 'Offer.docm', 'days30', '234F']) {
        expect(raw.contains(plain), isFalse, reason: plain);
      }

      // As after restarting the app.
      doneSteps.clear();
      ReminderPrefs.days1 = false;
      ReminderPrefs.days30 = true;
      SafetyLog.reports.value = const [];
      s = await open();
      await Vault.attach(s);
      await loadDoneSteps();
      await ReminderPrefs.load();
      await SafetyLog.load();
      expect(doneSteps, {'dob|STEP-MARKER'});
      expect(ReminderPrefs.days1, isTrue);
      expect(ReminderPrefs.days30, isFalse);
      final r = SafetyLog.reports.value.single;
      expect(r.fileName, 'Offer.docm');
      expect(r.scripts.single.what, contains('macro'));
      expect(r.sensitive.single.masked, '******234F');
      expect(r.shared, isTrue);
      await s.close();
    });

    test('a version 3 database gains the state table and keeps its papers', () async {
      final v3 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) => db.execute(
            'CREATE TABLE docs (row TEXT PRIMARY KEY, sealed TEXT NOT NULL)',
          ),
        ),
      );
      await v3.close();
      final s = await open();
      await s.saveMeta('x', {'a': 1});
      expect(await s.readMeta('x'), {'a': 1});
      expect(await s.all(), isEmpty);
      await s.close();
    });
  });
}
