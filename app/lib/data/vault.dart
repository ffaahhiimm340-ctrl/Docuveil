import 'dart:convert';

import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'vault_cipher.dart';

/// A document the vault knows about, plus where its copy lives.
class VaultDoc {
  const VaultDoc(this.doc, this.location, {this.fileName});

  final ExtractedDoc doc;
  final String location;

  /// Name of the file it was read from, when the owner added it.
  final String? fileName;

  /// The synthetic sample papers, as opposed to ones the owner added.
  bool get isDemo => doc.id.startsWith('demo-');
}

abstract class VaultStore {
  Future<List<VaultDoc>> all();
  Future<void> put(VaultDoc d);

  /// App state (choices, ticked steps): JSON-encodable values.
  Future<Object?> readMeta(String key);
  Future<void> saveMeta(String key, Object? value);
}

class MemoryVaultStore implements VaultStore {
  final _docs = <String, VaultDoc>{};

  @override
  Future<List<VaultDoc>> all() async => _docs.values.toList();

  @override
  Future<void> put(VaultDoc d) async => _docs[d.doc.id] = d;

  final _meta = <String, Object?>{};

  @override
  Future<Object?> readMeta(String key) async => _meta[key];

  @override
  Future<void> saveMeta(String key, Object? value) async => _meta[key] = value;
}

/// SQLite-backed store. Every record is encrypted with [VaultCipher]; the
/// database holds only keyed row names and sealed records.
class SqliteVaultStore implements VaultStore {
  SqliteVaultStore._(this._db, this._cipher);

  final Database _db;
  final VaultCipher _cipher;

  /// [factory] lets tests pass the FFI factory; [path] may be
  /// `inMemoryDatabasePath`. A database from an older version has its plain
  /// rows encrypted and the old data removed from the file.
  static Future<SqliteVaultStore> open(
    String path, {
    required VaultCipher cipher,
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    var migrated = false;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await _createSealed(db, 'docs');
          await _createSealed(db, 'meta');
        },
        onUpgrade: (db, from, _) async {
          if (from < 4) await _createSealed(db, 'meta');
          if (from >= 3) return; // already encrypted
          final hasFileName = from >= 2;
          await _createSealed(db, 'docs_sealed');
          for (final r in await db.query('docs')) {
            await _insert(
              db,
              'docs_sealed',
              cipher,
              id: r['id'] as String,
              record: {
                'id': r['id'],
                'doc_type': r['doc_type'],
                'location': r['location'],
                'fields': r['fields'],
                'text': r['text'],
                'file_name': hasFileName ? r['file_name'] : null,
              },
            );
          }
          await db.execute('DROP TABLE docs');
          await db.execute('ALTER TABLE docs_sealed RENAME TO docs');
          migrated = true;
        },
      ),
    );
    // Removes the old plain text from the file; not allowed in a transaction.
    if (migrated) await db.execute('VACUUM');
    return SqliteVaultStore._(db, cipher);
  }

  static Future<void> _createSealed(DatabaseExecutor db, String table) =>
      db.execute('CREATE TABLE $table (row TEXT PRIMARY KEY, sealed TEXT NOT NULL)');

  static Future<void> _insert(
    DatabaseExecutor db,
    String table,
    VaultCipher cipher, {
    required String id,
    required Map<String, Object?> record,
  }) async {
    final row = cipher.rowName(id);
    await db.insert(table, {
      'row': row,
      'sealed': await cipher.seal(jsonEncode(record), row),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static String pathIn(String dir) => p.join(dir, 'vault.db');

  @override
  Future<List<VaultDoc>> all() async {
    final out = <VaultDoc>[];
    for (final r in await _db.query('docs')) {
      final record =
          jsonDecode(await _cipher.open(r['sealed'] as String, r['row'] as String))
              as Map<String, dynamic>;
      out.add(
        VaultDoc(
          ExtractedDoc(
            id: record['id'] as String,
            type: DocType.values.byName(record['doc_type'] as String),
            fields: Map<String, String>.from(
              jsonDecode(record['fields'] as String) as Map,
            ),
            text: record['text'] as String,
          ),
          record['location'] as String,
          fileName: record['file_name'] as String?,
        ),
      );
    }
    out.sort((a, b) => a.doc.id.compareTo(b.doc.id));
    return out;
  }

  @override
  Future<void> put(VaultDoc d) => _insert(
    _db,
    'docs',
    _cipher,
    id: d.doc.id,
    record: {
      'id': d.doc.id,
      'doc_type': d.doc.type.name,
      'location': d.location,
      'fields': jsonEncode(d.doc.fields),
      'text': d.doc.text,
      'file_name': d.fileName,
    },
  );

  @override
  Future<Object?> readMeta(String key) async {
    final row = _cipher.rowName('meta|$key');
    final rows = await _db.query('meta', where: 'row = ?', whereArgs: [row]);
    if (rows.isEmpty) return null;
    return jsonDecode(await _cipher.open(rows.single['sealed'] as String, row));
  }

  @override
  Future<void> saveMeta(String key, Object? value) async {
    final row = _cipher.rowName('meta|$key');
    await _db.insert('meta', {
      'row': row,
      'sealed': await _cipher.seal(jsonEncode(value), row),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => _db.close();
}

/// The vault the screens read. Starts with the demo papers so the app works
/// before any database is attached (and in widget tests).
class Vault {
  Vault._();

  static final ValueNotifier<List<VaultDoc>> docs = ValueNotifier(demoDocs());

  static VaultStore? _store;
  static final _memory = MemoryVaultStore();

  /// App state, saved with the vault's encryption once a store is attached.
  static Future<Object?> readMeta(String key) =>
      (_store ?? _memory).readMeta(key);
  static Future<void> saveMeta(String key, Object? value) =>
      (_store ?? _memory).saveMeta(key, value);

  /// Save a paper (to the attached store when there is one) and show it.
  static Future<void> add(VaultDoc d) async {
    await _store?.put(d);
    docs.value = [
      for (final x in docs.value)
        if (x.doc.id != d.doc.id) x,
      d,
    ];
  }

  /// Load from [store]; if it is empty, fill it with the demo papers.
  static Future<void> attach(VaultStore store) async {
    var stored = await store.all();
    _store = store;
    if (stored.isEmpty) {
      for (final d in demoDocs()) {
        await store.put(d);
      }
      stored = await store.all();
    }
    docs.value = stored;
  }
}

/// Synthetic sample person from the design (Asha Verma). Not real data.
List<VaultDoc> demoDocs() => const [
  VaultDoc(
    ExtractedDoc(
      id: 'demo-aadhaar',
      type: DocType.aadhaar,
      fields: {
        'name': 'Asha R. Verma',
        'dob': '04 Jul 2001',
        'father_name': 'Rajesh Verma',
      },
    ),
    'Phone',
  ),
  VaultDoc(
    ExtractedDoc(
      id: 'demo-pan',
      type: DocType.pan,
      fields: {
        'name': 'Asha Rajesh Verma',
        'dob': '04 Jul 2001',
        'father_name': 'R Verma',
      },
    ),
    'Laptop',
  ),
  VaultDoc(
    ExtractedDoc(
      id: 'demo-marksheet',
      type: DocType.marksheet,
      fields: {
        'name': 'Asha Rajesh Verma',
        'dob': '14 Jul 2001',
        'father_name': 'Rajesh Verma',
      },
    ),
    'Drive',
  ),
  VaultDoc(
    ExtractedDoc(
      id: 'demo-certificate',
      type: DocType.certificate,
      fields: {'name': 'Asha Rajesh Varma'},
    ),
    'Laptop',
  ),
];
