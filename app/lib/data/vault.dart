import 'dart:convert';

import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
}

class MemoryVaultStore implements VaultStore {
  final _docs = <String, VaultDoc>{};

  @override
  Future<List<VaultDoc>> all() async => _docs.values.toList();

  @override
  Future<void> put(VaultDoc d) async => _docs[d.doc.id] = d;
}

/// SQLite-backed store. NOT encrypted yet: SQLCipher and a keystore-held key
/// are still to do (the research plan calls for encrypted storage).
class SqliteVaultStore implements VaultStore {
  SqliteVaultStore._(this._db);

  final Database _db;

  /// [factory] lets tests pass the FFI factory; [path] may be
  /// `inMemoryDatabasePath`.
  static Future<SqliteVaultStore> open(
    String path, {
    DatabaseFactory? factory,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onUpgrade: (db, from, _) async {
          if (from < 2) {
            await db.execute('ALTER TABLE docs ADD COLUMN file_name TEXT');
          }
        },
        onCreate: (db, _) => db.execute('''
          CREATE TABLE docs (
            id TEXT PRIMARY KEY,
            doc_type TEXT NOT NULL,
            location TEXT NOT NULL,
            fields TEXT NOT NULL,
            text TEXT NOT NULL,
            file_name TEXT
          )'''),
      ),
    );
    return SqliteVaultStore._(db);
  }

  static String pathIn(String dir) => p.join(dir, 'vault.db');

  @override
  Future<List<VaultDoc>> all() async {
    final rows = await _db.query('docs', orderBy: 'id');
    return [
      for (final r in rows)
        VaultDoc(
          ExtractedDoc(
            id: r['id'] as String,
            type: DocType.values.byName(r['doc_type'] as String),
            fields: Map<String, String>.from(
              jsonDecode(r['fields'] as String) as Map,
            ),
            text: r['text'] as String,
          ),
          r['location'] as String,
          fileName: r['file_name'] as String?,
        ),
    ];
  }

  @override
  Future<void> put(VaultDoc d) => _db.insert('docs', {
    'id': d.doc.id,
    'doc_type': d.doc.type.name,
    'location': d.location,
    'fields': jsonEncode(d.doc.fields),
    'text': d.doc.text,
    'file_name': d.fileName,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> close() => _db.close();
}

/// The vault the screens read. Starts with the demo papers so the app works
/// before any database is attached (and in widget tests).
class Vault {
  Vault._();

  static final ValueNotifier<List<VaultDoc>> docs = ValueNotifier(demoDocs());

  static VaultStore? _store;

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
    _store = store;
    var stored = await store.all();
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
