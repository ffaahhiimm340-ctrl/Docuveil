// End-to-end check of cross-device alerts against a running relay.
//
//   (server) uvicorn app.main:app --port 8765   with DATABASE_URL set
//   dart run bin/sync_e2e.dart http://127.0.0.1:8765 50
//
// Two simulated devices share one pairing secret. Device A holds the original
// marksheet; device B's copy gets edited. We measure the time from B's push
// until A, polling every [pollMs], raises the alert. Then we check what the
// relay stored: no field names or values, and nothing an outsider holding the
// same document could match (confirmation-of-file).
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:docuveil_engine/relay.dart';
import 'package:http/http.dart' as http;

const pollMs = 100;

ExtractedDoc marks(String id, String cgpa) => ExtractedDoc(
  id: id,
  type: DocType.marksheet,
  fields: {'name': 'Rahul Sharma', 'seat_number': 'S482913', 'cgpa': cgpa},
);

String randomId(Random r) =>
    List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();

Future<void> main(List<String> args) async {
  final base = Uri.parse(args.isNotEmpty ? args[0] : 'http://127.0.0.1:8765');
  final rounds = args.length > 1 ? int.parse(args[1]) : 20;
  final rnd = Random(42);
  final secret = PairingSecret.generate();
  final a = RelayClient(base, secret, 'dev-${randomId(rnd)}');
  final b = RelayClient(base, secret, 'dev-${randomId(rnd)}');

  final latencies = <int>[];
  var since = 0, falseAlerts = 0;
  for (var i = 0; i < rounds; i++) {
    final id = 'marksheet-$i';
    final mine = fingerprint(secret.key, marks(id, '8.74'));
    final local = {mine.docTag: mine};

    // B first reports an identical copy: A must stay quiet.
    await b.push(fingerprint(secret.key, marks(id, '8.740')));
    final quiet = await a.pull(since: since);
    since = quiet.map((e) => e.seq).fold(since, max);
    falseAlerts += detectDivergence(
      secret.key,
      local: local,
      remote: quiet,
      knownFields: marks(id, '').fields.keys,
      availability: (_) => const AvailabilityInput(copies: 2),
    ).length;

    // Then B's copy is edited.
    final sw = Stopwatch()..start();
    await b.push(fingerprint(secret.key, marks(id, '9.40')));
    while (true) {
      final got = await a.pull(since: since);
      since = got.map((e) => e.seq).fold(since, max);
      final alerts = detectDivergence(
        secret.key,
        local: local,
        remote: got,
        knownFields: marks(id, '').fields.keys,
        availability: (_) => const AvailabilityInput(copies: 2),
      );
      if (alerts.isNotEmpty) {
        if (alerts.single.changedFields.join() != 'cgpa') {
          throw StateError('wrong field: ${alerts.single.changedFields}');
        }
        break;
      }
      if (sw.elapsedMilliseconds > 10000) throw StateError('no alert in 10 s');
      await Future<void>.delayed(const Duration(milliseconds: pollMs));
    }
    latencies.add(sw.elapsedMilliseconds);
  }
  latencies.sort();
  int pctl(double p) => latencies[((latencies.length - 1) * p).round()];
  print('== Cross-device alert latency ($rounds rounds, poll every $pollMs ms) ==');
  print('median ${pctl(0.5)} ms, p95 ${pctl(0.95)} ms, max ${latencies.last} ms');
  print('false alerts on identical/reformatted copies: $falseAlerts');

  // What the relay holds for this owner (a third device id sees every row).
  final res = await http.get(base.replace(
    path: '/v1/${secret.ownerToken}/changes',
    queryParameters: {'device_id': 'observer', 'since': '0'},
  ));
  final stored = res.body;
  final rows = (jsonDecode(stored) as Map)['changes'] as List;
  final plain = ['cgpa', 'seat_number', 'Rahul', '8.74', '9.40', 'S482913', 'marksheet'];
  final leaked = plain.where(stored.contains).toList();

  // Outsider holding the same document, without the key: plain hashes, or
  // HMAC under any other key, must never match a stored tag.
  final tags = <String>{
    for (final r in rows) ...[r['doc'] as String, ...(r['fields'] as Map).values.cast<String>()],
  };
  final guesses = <String>{
    for (final v in ['8.74', '9.40', 'Rahul Sharma', 'rahul sharma', 'S482913'])
      sha256.convert(utf8.encode(v)).toString(),
    ...fingerprint(List.generate(32, (_) => rnd.nextInt(256)), marks('marksheet-0', '8.74'))
        .fields.values,
  };
  print('\n== What the relay stored ==');
  print('rows: ${rows.length}; plaintext found: ${leaked.isEmpty ? 'none' : leaked}');
  print('outsider guesses matching a stored tag: ${guesses.intersection(tags).length}');
  print('visible to the relay: owner token, device ids, timing, '
      '${rows.isEmpty ? 0 : (rows.first['fields'] as Map).length} field tags per document');
  a.close();
  b.close();
}
