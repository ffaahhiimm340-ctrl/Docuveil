// Field-extraction accuracy on rendered synthetic documents, and what
// extraction errors do to tamper detection.
//
//   py -3.12 dataset/render_text.py --people 100 --out dataset/generated
//   dart run bin/extract_eval.dart ../../dataset/generated
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:docuveil_engine/docuveil_engine.dart';

String pct(num a, num b) => b == 0 ? 'n/a' : '${(100 * a / b).toStringAsFixed(1)}%';

void main(List<String> args) {
  final dir = args.isEmpty ? '../../dataset/generated' : args.first;
  final rows = File('$dir/extraction.jsonl')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();

  // 1. Per-field accuracy: extracted value equals gold after normalisation.
  final ok = <String, int>{}, total = <String, int>{};
  final docOk = <double, int>{}, docTotal = <double, int>{};
  final misses = <String>[];
  for (final r in rows) {
    final type = DocType.values.byName(r['doc_type'] as String);
    final noise = (r['noise'] as num).toDouble();
    final gold = Map<String, String>.from(r['fields'] as Map);
    final got = extractFields(type, r['text'] as String);
    var allRight = true;
    for (final e in gold.entries) {
      final k = '$noise ${type.name}.${e.key}';
      total[k] = (total[k] ?? 0) + 1;
      final g = got[e.key];
      if (g != null && normalizeField(e.key, g) == normalizeField(e.key, e.value)) {
        ok[k] = (ok[k] ?? 0) + 1;
      } else {
        allRight = false;
        if (noise == 0 && misses.length < 8) misses.add('${type.name}.${e.key}: gold "${e.value}" got "$g"');
      }
    }
    docTotal[noise] = (docTotal[noise] ?? 0) + 1;
    if (allRight) docOk[noise] = (docOk[noise] ?? 0) + 1;
  }
  print('== Field extraction (${rows.length ~/ 3} documents x 3 noise levels) ==');
  for (final noise in [0.0, 0.02, 0.05]) {
    final keys = total.keys.where((k) => k.startsWith('$noise ')).toList()..sort();
    final f = keys.fold(0, (a, k) => a + (ok[k] ?? 0));
    final n = keys.fold(0, (a, k) => a + total[k]!);
    final worst = keys.map((k) => (k.substring(k.indexOf(' ') + 1), (ok[k] ?? 0) / total[k]!)).toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    print('noise ${(noise * 100).toStringAsFixed(0)}%: fields ${pct(f, n)}, whole documents ${pct(docOk[noise] ?? 0, docTotal[noise]!)}; '
        'weakest: ${worst.take(3).map((w) => '${w.$1} ${(w.$2 * 100).toStringAsFixed(0)}%').join(', ')}');
  }
  if (misses.isNotEmpty) {
    print('clean-text misses (first ${misses.length}):');
    for (final m in misses) {
      print('  $m');
    }
  }

  // 2. End to end: baseline from the clean text; a re-scan (noisy text of the
  //    same document) must not be reported as tampering.
  final byId = <String, Map<double, Map<String, dynamic>>>{};
  for (final r in rows) {
    byId.putIfAbsent(r['id'] as String, () => {})[(r['noise'] as num).toDouble()] = r;
  }
  for (final noise in [0.02, 0.05]) {
    final counts = <Verdict, int>{};
    final blame = <String, int>{};
    for (final v in byId.values) {
      final type = DocType.values.byName(v[0.0]!['doc_type'] as String);
      ExtractedDoc doc(Map<String, dynamic> r) => ExtractedDoc(
        id: r['id'] as String,
        type: type,
        fields: extractFields(type, r['text'] as String),
        text: r['text'] as String,
      );
      final base = DocSnapshot.fromBytes(Uint8List.fromList([1]), doc(v[0.0]!));
      final scan = DocSnapshot.fromBytes(Uint8List.fromList([2]), doc(v[noise]!));
      final report = compareVersions(base, scan);
      counts[report.verdict] = (counts[report.verdict] ?? 0) + 1;
      if (report.verdict == Verdict.tampered) {
        for (final c in report.changes.where((c) => !c.possibleOcr)) {
          final k = '${type.name}.${c.field}';
          blame[k] = (blame[k] ?? 0) + 1;
          if (blame[k] == 1) print('    e.g. $k: "${c.oldValue}" -> "${c.newValue}"');
        }
      }
    }
    final top = blame.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    print('re-scan at ${(noise * 100).toStringAsFixed(0)}% noise -> '
        '${Verdict.values.map((v) => '${v.name} ${pct(counts[v] ?? 0, byId.length)}').join(', ')}');
    print('  false "tampered" caused by: ${top.take(6).map((e) => '${e.key} ${e.value}').join(', ')}');
  }

  // 3. The other side: a real edit in the printed text, then a noisy
  //    re-scan of the edited document. It must still be caught.
  final rng = Random(9);
  for (final noise in [0.0, 0.02, 0.05]) {
    final counts = <Verdict, int>{};
    var n = 0;
    for (final v in byId.values) {
      final clean = v[0.0]!;
      final type = DocType.values.byName(clean['doc_type'] as String);
      final text = clean['text'] as String;
      final gold = Map<String, String>.from(clean['fields'] as Map);
      final editable = gold.entries
          .where((e) => text.contains(e.value) && RegExp(r'\d').hasMatch(e.value))
          .toList();
      if (editable.isEmpty) continue;
      final e = editable[rng.nextInt(editable.length)];
      // Change one digit to a different digit (a forger's edit).
      final idx = [for (var i = 0; i < e.value.length; i++) if (RegExp(r'\d').hasMatch(e.value[i])) i];
      final i = idx[rng.nextInt(idx.length)];
      final d = (int.parse(e.value[i]) + 1 + rng.nextInt(8)) % 10;
      final edited = text.replaceFirst(e.value, e.value.replaceRange(i, i + 1, '$d'));
      final scanned = noise == 0 ? edited : _noise(rng, edited, noise);
      ExtractedDoc doc(String t) => ExtractedDoc(
        id: clean['id'] as String,
        type: type,
        fields: extractFields(type, t),
        text: t,
      );
      final verdict = compareVersions(
        DocSnapshot.fromBytes(Uint8List.fromList([1]), doc(text)),
        DocSnapshot.fromBytes(Uint8List.fromList([2]), doc(scanned)),
      ).verdict;
      counts[verdict] = (counts[verdict] ?? 0) + 1;
      n++;
    }
    print('one digit edited, re-scan at ${(noise * 100).toStringAsFixed(0)}% noise ($n docs) -> '
        '${Verdict.values.map((v) => '${v.name} ${pct(counts[v] ?? 0, n)}').join(', ')}');
  }
}

/// Same OCR-style confusions as dataset/render_text.py.
String _noise(Random r, String text, double rate) {
  const swaps = {'O': '0', '0': 'O', 'l': '1', '1': 'l', 'I': 'l', 'S': '5', 'B': '8', 'e': 'c', 'm': 'rn'};
  return text.split('').map((c) => swaps.containsKey(c) && r.nextDouble() < rate ? swaps[c]! : c).join();
}
