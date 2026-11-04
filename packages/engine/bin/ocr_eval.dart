// Field extraction and tamper verdicts on real OCR output (RapidOCR on
// rendered, scanned-looking synthetic documents).
//
//   dataset/.venv/Scripts/python dataset/scan_ocr.py --people 20 --out dataset/generated
//   dart run bin/ocr_eval.dart ../../dataset/generated
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:docuveil_engine/docuveil_engine.dart';

String pct(num a, num b) => b == 0 ? 'n/a' : '${(100 * a / b).toStringAsFixed(1)}%';

void main(List<String> args) {
  final dir = args.isEmpty ? '../../dataset/generated' : args.first;
  final rows = File('$dir/ocr.jsonl')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();
  final docs = <String, Map<String, Map<String, dynamic>>>{};
  for (final r in rows) {
    docs.putIfAbsent(r['id'] as String, () => {})[r['variant'] as String] = r;
  }

  DocType typeOf(Map<String, dynamic> r) => DocType.values.byName(r['doc_type'] as String);
  ExtractedDoc read(Map<String, dynamic> r) => ExtractedDoc(
    id: r['id'] as String,
    type: typeOf(r),
    fields: extractFields(typeOf(r), r['text'] as String),
    text: r['text'] as String,
  );
  // 1. Field accuracy on the original scans.
  final ok = <String, int>{}, total = <String, int>{};
  final misses = <String, String>{};
  for (final v in docs.values) {
    final r = v['original']!;
    final got = read(r).fields;
    for (final e in Map<String, String>.from(r['fields'] as Map).entries) {
      final k = '${typeOf(r).name}.${e.key}';
      total[k] = (total[k] ?? 0) + 1;
      final g = got[e.key];
      if (g != null && normalizeField(e.key, g) == normalizeField(e.key, e.value)) {
        ok[k] = (ok[k] ?? 0) + 1;
      } else {
        misses.putIfAbsent(k, () => 'gold "${e.value}" got "$g"');
      }
    }
  }
  final f = ok.values.fold(0, (a, b) => a + b), n = total.values.fold(0, (a, b) => a + b);
  final ranked = total.keys.toList()..sort((a, b) => ((ok[a] ?? 0) / total[a]!).compareTo((ok[b] ?? 0) / total[b]!));
  print('== Real OCR: ${docs.length} documents, ${rows.length} scans ==');
  print('fields read correctly: ${pct(f, n)}');
  for (final k in ranked.take(6)) {
    print('  $k ${pct(ok[k] ?? 0, total[k]!)}   e.g. ${misses[k] ?? ''}');
  }

  // The app asks the owner to correct what was misread and type what was not
  // read when adding a paper. "confirmed" simulates a careful owner doing so;
  // "as read" trusts the OCR of the first scan, as a careless owner would.
  ExtractedDoc confirmed(Map<String, dynamic> r) => ExtractedDoc(
    id: r['id'] as String,
    type: typeOf(r),
    fields: Map<String, String>.from(r['fields'] as Map),
    text: r['text'] as String,
  );
  ChangeReport compareWith(ExtractedDoc base, Map<String, dynamic> b) => compareVersions(
    DocSnapshot.fromBytes(Uint8List.fromList([1]), base),
    DocSnapshot.fromBytes(Uint8List.fromList([2]), read(b)),
  );

  String line(Map<Verdict, int> c, int n) =>
      Verdict.values.map((x) => '${x.name} ${pct(c[x] ?? 0, n)}').join(', ');

  var textDiff = 0;
  for (final v in docs.values) {
    if (v['original']!['text'] != v['rescan']!['text']) textDiff++;
  }
  print('\nbaselines on unchanged re-scans: plain SHA-256 alarms on 100.0%, plain OCR-text diff on ${pct(textDiff, docs.length)}');

  for (final mode in ['as read', 'confirmed']) {
    ExtractedDoc baseOf(Map<String, dynamic> r) => mode == 'confirmed' ? confirmed(r) : read(r);

    // Unchanged document scanned twice: must not be called tampered.
    final re = <Verdict, int>{};
    final falseAlarms = <String>[];
    for (final v in docs.values) {
      final r = compareWith(baseOf(v['original']!), v['rescan']!);
      re[r.verdict] = (re[r.verdict] ?? 0) + 1;
      if (r.verdict == Verdict.tampered && falseAlarms.length < 6) {
        falseAlarms.add('${v['original']!['doc_type']}: ${r.summary()}');
      }
    }
    print('\n--- baseline $mode ---');
    print('unchanged, scanned twice -> ${line(re, docs.length)}');
    for (final a in falseAlarms) {
      print('  false alarm: $a');
    }

    // One digit edited, then scanned: must be flagged, ideally naming the field.
    final ed = <Verdict, int>{};
    var edits = 0, named = 0;
    final missed = <String>[];
    for (final v in docs.values) {
      final e = v['edited'];
      if (e == null) continue;
      edits++;
      final r = compareWith(baseOf(v['original']!), e);
      ed[r.verdict] = (ed[r.verdict] ?? 0) + 1;
      final field = (e['edit'] as Map)['field'] as String;
      if (r.changes.any((c) => c.field == field)) named++;
      if (r.verdict != Verdict.tampered && r.verdict != Verdict.review && missed.length < 6) {
        missed.add('${e['doc_type']}.$field ${(e['edit'] as Map)['old']} -> ${(e['edit'] as Map)['new']}');
      }
    }
    print('one digit edited, then scanned ($edits) -> ${line(ed, edits)}');
    print('  edited field named in the report: ${pct(named, edits)}');
    for (final m in missed) {
      print('  missed: $m');
    }
  }
}
