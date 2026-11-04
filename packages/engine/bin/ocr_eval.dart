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
  ChangeReport compare(Map<String, dynamic> a, Map<String, dynamic> b) => compareVersions(
    DocSnapshot.fromBytes(Uint8List.fromList([1]), read(a)),
    DocSnapshot.fromBytes(Uint8List.fromList([2]), read(b)),
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

  // 2. Unchanged document scanned twice: must not be called tampered.
  final re = <Verdict, int>{};
  var textDiff = 0;
  final falseAlarms = <String>[];
  for (final v in docs.values) {
    final r = compare(v['original']!, v['rescan']!);
    re[r.verdict] = (re[r.verdict] ?? 0) + 1;
    if (v['original']!['text'] != v['rescan']!['text']) textDiff++;
    if (r.verdict == Verdict.tampered && falseAlarms.length < 5) {
      falseAlarms.add('${v['original']!['doc_type']}: ${r.summary()}');
    }
  }
  print('\nunchanged, scanned twice -> ${Verdict.values.map((x) => '${x.name} ${pct(re[x] ?? 0, docs.length)}').join(', ')}');
  print('  baselines: plain SHA-256 alarms on 100.0%, plain OCR-text diff on ${pct(textDiff, docs.length)}');
  for (final a in falseAlarms) {
    print('  false alarm: $a');
  }

  // 3. One digit edited, then scanned: must be caught, ideally naming the field.
  final ed = <Verdict, int>{};
  var edits = 0, named = 0;
  final missed = <String>[];
  for (final v in docs.values) {
    final e = v['edited'];
    if (e == null) continue;
    edits++;
    final r = compare(v['original']!, e);
    ed[r.verdict] = (ed[r.verdict] ?? 0) + 1;
    final field = (e['edit'] as Map)['field'] as String;
    if (r.changes.any((c) => c.field == field)) named++;
    if (r.verdict != Verdict.tampered && r.verdict != Verdict.review && missed.length < 5) {
      missed.add('${e['doc_type']}.$field ${(e['edit'] as Map)['old']} -> ${(e['edit'] as Map)['new']}');
    }
  }
  print('\none digit edited, then scanned ($edits) -> ${Verdict.values.map((x) => '${x.name} ${pct(ed[x] ?? 0, edits)}').join(', ')}');
  print('  edited field named in the report: ${pct(named, edits)}');
  for (final m in missed) {
    print('  missed: $m');
  }
}
