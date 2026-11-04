import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'vault.dart';

/// What the safety checks found in one file the owner added.
class FileReport {
  const FileReport({
    required this.fileName,
    this.path,
    this.scripts = const [],
    this.sensitive = const [],
    this.shared = false,
  });

  final String fileName;
  final String? path;
  final List<ScriptFinding> scripts;
  final List<SensitiveFinding> sensitive;

  /// The file is somewhere other people can probably open.
  final bool shared;

  bool get needsAttention => scripts.isNotEmpty || (shared && sensitive.isNotEmpty);
}

/// Results of the checks run on added files, for the Safety centre. Kept for
/// this run of the app only.
class SafetyLog {
  SafetyLog._();

  static final ValueNotifier<List<FileReport>> reports = ValueNotifier(const []);

  static FileReport check(String fileName, String? path, Uint8List bytes, String text) {
    final r = FileReport(
      fileName: fileName,
      path: path,
      scripts: scanForHiddenScript(fileName, bytes),
      sensitive: findSensitive(text),
      shared: path != null && looksShared(path),
    );
    reports.value = [r, ...reports.value];
    save();
    return r;
  }

  static Future<void> save() => Vault.saveMeta('safety_reports', [
    for (final r in reports.value)
      {
        'file': r.fileName,
        'path': r.path,
        'scripts': [for (final s in r.scripts) s.what],
        'sensitive': [
          for (final s in r.sensitive) [s.kind, s.masked],
        ],
        'shared': r.shared,
      },
  ]);

  static Future<void> load() async {
    final v = await Vault.readMeta('safety_reports');
    if (v is! List) return;
    reports.value = [
      for (final r in v.cast<Map>())
        FileReport(
          fileName: r['file'] as String,
          path: r['path'] as String?,
          scripts: [
            for (final s in (r['scripts'] as List).cast<String>()) ScriptFinding(s),
          ],
          sensitive: [
            for (final s in (r['sensitive'] as List).cast<List>())
              SensitiveFinding(s[0] as String, s[1] as String),
          ],
          shared: r['shared'] as bool,
        ),
    ];
  }
}

/// Ransomware guard for desktop: decoy files that nothing should ever touch,
/// and a watch for many files changing at once. Off until the owner turns it
/// on, because it writes files. Known limit: decoy-aware ransomware can skip
/// decoys, and this only warns; it does not stop anything.
class DecoyGuard {
  DecoyGuard._();

  static const folderName = '.docuveil-decoys';
  static const _files = {
    'Bank_Passwords_old.txt': 'Docuveil decoy file. Please do not edit or delete it.\n',
    'Tax_Return_scan.txt': 'Docuveil decoy file. Please do not edit or delete it.\n',
    'Family_IDs_backup.txt': 'Docuveil decoy file. Please do not edit or delete it.\n',
  };

  /// True while the guard is on.
  static final ValueNotifier<bool> active = ValueNotifier(false);

  /// Why it tripped, or null when all is well.
  static final ValueNotifier<String?> alarm = ValueNotifier(null);

  static Directory? _dir;
  static final Map<String, String> _hashes = {};
  static StreamSubscription<FileSystemEvent>? _decoyWatch;
  static StreamSubscription<FileSystemEvent>? _burstWatch;

  static bool get supported =>
      !kIsWeb &&
      const {
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  static String _hash(File f) => sha256.convert(f.readAsBytesSync()).toString();

  /// Create the decoys in [parent] and start watching.
  static Future<void> enable(Directory parent, {bool watch = true}) async {
    final dir = Directory(p.join(parent.path, folderName));
    await dir.create(recursive: true);
    _hashes.clear();
    for (final e in _files.entries) {
      final f = File(p.join(dir.path, e.key));
      await f.writeAsString(e.value);
      _hashes[f.path] = _hash(f);
    }
    _dir = dir;
    alarm.value = null;
    active.value = true;
    if (!watch) return;
    _decoyWatch = dir.watch().listen((_) => verify());
    final burst = MassChangeDetector();
    _burstWatch = parent.watch(recursive: true).listen((e) {
      if (e.path.contains(folderName)) return;
      if (burst.record(e.path, DateTime.now())) {
        alarm.value ??= 'Many files changed at once in ${parent.path}.';
      }
    });
  }

  /// Compare the decoys with how they were written. Returns false if tripped.
  static bool verify() {
    for (final e in _hashes.entries) {
      final f = File(e.key);
      if (!f.existsSync()) {
        alarm.value ??= 'A decoy file was deleted: ${p.basename(e.key)}.';
        return false;
      }
      if (_hash(f) != e.value) {
        alarm.value ??= 'A decoy file was changed: ${p.basename(e.key)}.';
        return false;
      }
    }
    return true;
  }

  /// Stop watching and remove the decoys this guard created (nothing else).
  static Future<void> disable() async {
    await _decoyWatch?.cancel();
    await _burstWatch?.cancel();
    _decoyWatch = _burstWatch = null;
    for (final path in _hashes.keys) {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    }
    final d = _dir;
    if (d != null && d.existsSync() && d.listSync().isEmpty) await d.delete();
    _hashes.clear();
    _dir = null;
    alarm.value = null;
    active.value = false;
  }
}
