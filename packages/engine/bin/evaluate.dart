// Scores the engine against the synthetic dataset and the plan's baselines.
//
//   py -3.12 dataset/generate.py --people 50 --out dataset/generated
//   dart run bin/evaluate.dart ../../dataset/generated
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:docuveil_engine/docuveil_engine.dart';

List<Map<String, dynamic>> readJsonl(String path) => File(path)
    .readAsLinesSync()
    .where((l) => l.trim().isNotEmpty)
    .map((l) => jsonDecode(l) as Map<String, dynamic>)
    .toList();

/// Every copy in the dataset is a different file (a re-save changes bytes
/// without changing content), so [version] is mixed into the simulated bytes.
DocSnapshot snap(Map<String, dynamic> d, int version) => DocSnapshot.fromBytes(
  Uint8List.fromList(utf8.encode('${jsonEncode(d)}#$version')),
  ExtractedDoc.fromJson(d),
);

String pct(num a, num b) => b == 0 ? 'n/a' : '${(100 * a / b).toStringAsFixed(1)}%';

void tamperEval(String dir) {
  final tamper = readJsonl('$dir/tamper.jsonl');
  final harmless = readJsonl('$dir/harmless.jsonl');
  var tp = 0, fn = 0, exactField = 0, fp = 0;
  var shaFp = 0, textDiffFp = 0;
  for (final c in tamper) {
    final r = compareVersions(snap(c['baseline'], 1), snap(c['current'], 2));
    if (r.verdict == Verdict.tampered) {
      tp++;
      final want = (c['label']['changed_fields'] as Map).cast<String, dynamic>();
      final got = {for (final ch in r.changes) ch.field: [ch.oldValue, ch.newValue]};
      if (want.length == got.length &&
          want.entries.every(
            (e) => got[e.key]?.join('|') == (e.value as List).join('|'),
          )) {
        exactField++;
      }
    } else {
      fn++;
    }
  }
  for (final c in harmless) {
    final r = compareVersions(snap(c['baseline'], 1), snap(c['current'], 2));
    if (r.verdict == Verdict.tampered) fp++;
    shaFp++; // plain SHA-256 flags every changed file
    if (c['baseline']['text'] != c['current']['text'] ||
        jsonEncode(c['baseline']['fields']) != jsonEncode(c['current']['fields'])) {
      textDiffFp++;
    }
  }
  final prec = tp / (tp + fp), rec = tp / (tp + fn);
  print('== Tamper detection (${tamper.length} tampered, ${harmless.length} harmless) ==');
  print('engine     precision ${pct(tp, tp + fp)}  recall ${pct(tp, tp + fn)}  '
      'F1 ${(2 * prec * rec / (prec + rec)).toStringAsFixed(3)}');
  print('exact field + old/new values correct: ${pct(exactField, tamper.length)}');
  print('false-alarm rate on harmless changes: engine ${pct(fp, harmless.length)}, '
      'plain SHA-256 ${pct(shaFp, harmless.length)}, plain text/field diff ${pct(textDiffFp, harmless.length)}');
}

const _auditFields = ['name', 'dob', 'gender', 'father_name'];

void auditEval(String dir) {
  final cases = readJsonl('$dir/audit.jsonl');
  var tp = 0, fp = 0, fn = 0;
  var bTp = 0, bFp = 0, bFn = 0;
  var levelOk = 0, levelTotal = 0;
  for (final c in cases) {
    final docs = [
      for (final d in c['documents'] as List) ExtractedDoc.fromJson(d),
    ];
    final labels = (c['label']['mismatches'] as List).cast<Map<String, dynamic>>();
    final want = {
      for (final m in labels)
        if (m['level'] != 'equivalent') m['field'] as String,
    };
    final report = audit(docs);
    final got = {for (final m in report.actionable) m.field};
    tp += got.intersection(want).length;
    fp += got.difference(want).length;
    fn += want.difference(got).length;

    // Baseline: generic string similarity, exact match for dob/gender.
    final flagged = <String>{};
    for (final f in _auditFields) {
      final vs = [for (final d in docs) if (d.fields[f] != null) d.fields[f]!];
      for (var i = 0; i < vs.length; i++) {
        for (var j = i + 1; j < vs.length; j++) {
          final same = (f == 'name' || f == 'father_name')
              ? jaroWinkler(vs[i].toLowerCase(), vs[j].toLowerCase()) >= 0.9
              : vs[i].trim().toLowerCase() == vs[j].trim().toLowerCase();
          if (!same) flagged.add(f);
        }
      }
    }
    bTp += flagged.intersection(want).length;
    bFp += flagged.difference(want).length;
    bFn += want.difference(flagged).length;

    for (final m in labels) {
      levelTotal++;
      final hit = report.mismatches.where(
        (x) =>
            x.field == m['field'] &&
            (m['docs'] as List).contains(x.docA.id) &&
            (m['docs'] as List).contains(x.docB.id),
      );
      final got = hit.isEmpty ? 'equivalent' : hit.first.level.name;
      if (got == m['level']) levelOk++;
    }
  }
  double f1(int t, int p, int n) => 2 * t / (2 * t + p + n);
  print('\n== Consistency audit (${cases.length} cases) ==');
  print('engine   precision ${pct(tp, tp + fp)}  recall ${pct(tp, tp + fn)}  F1 ${f1(tp, fp, fn).toStringAsFixed(3)}');
  print('baseline precision ${pct(bTp, bTp + bFp)}  recall ${pct(bTp, bTp + bFn)}  F1 ${f1(bTp, bFp, bFn).toStringAsFixed(3)}  (generic Jaro-Winkler 0.9 / exact)');
  print('level accuracy (equivalent / likelyProblem / blocking): ${pct(levelOk, levelTotal)}');
}

void main(List<String> args) {
  final dir = args.isEmpty ? '../../dataset/generated' : args.first;
  tamperEval(dir);
  auditEval(dir);
}

