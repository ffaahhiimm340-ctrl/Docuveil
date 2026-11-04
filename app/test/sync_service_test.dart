import 'dart:convert';

import 'package:docuveil/data/derived.dart';
import 'package:docuveil/data/pin_lock.dart';
import 'package:docuveil/data/sync_service.dart';
import 'package:docuveil/data/vault.dart';
import 'package:docuveil_engine/docuveil_engine.dart'
    show DocType, ExtractedDoc, Urgency;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The relay's behaviour, in memory.
MockClient fakeRelay(List<String> seenBodies) {
  final log = <Map<String, dynamic>>[];
  return MockClient((req) async {
    if (req.method == 'POST') {
      seenBodies.add(req.body);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      log.add({'seq': log.length + 1, 'ts': 0.0, ...body});
      return http.Response(jsonEncode({'seq': log.length}), 200);
    }
    final me = req.url.queryParameters['device_id'];
    final since = int.parse(req.url.queryParameters['since']!);
    return http.Response(
      jsonEncode({
        'changes': [
          for (final e in log)
            if ((e['seq'] as int) > since && e['device_id'] != me) e,
        ],
      }),
      200,
    );
  });
}

VaultDoc marksheet(String cgpa, {String id = 'a'}) => VaultDoc(
  ExtractedDoc(
    id: id,
    type: DocType.marksheet,
    fields: {'name': 'Asha Verma', 'seat_number': 'S482913', 'cgpa': cgpa},
  ),
  'This device',
);

void main() {
  late List<String> sent;
  late SyncService a, b;

  setUp(() async {
    sent = [];
    final relay = fakeRelay(sent);
    a = SyncService(store: MemoryPinStore(), client: relay);
    b = SyncService(store: MemoryPinStore(), client: relay);
    await a.load();
    await b.load();
    final s = await a.secretOrCreate();
    await b.join(s.encode());
    await a.setRelayUrl('http://relay.test');
    await b.setRelayUrl('http://relay.test');
  });

  test('pairing gives both devices the same key but their own random ids', () {
    expect(b.secret!.key, a.secret!.key);
    expect(a.deviceId, isNot(b.deviceId));
    expect(a.deviceId, startsWith('dev-'));
  });

  test('an edited copy on the other device raises an alert naming the field', () async {
    await a.syncNow([marksheet('8.74', id: 'file-on-a')]);
    // Different file (so a different vault id), same paper, edited CGPA.
    final r = await b.syncNow([marksheet('9.40', id: 'file-on-b')]);
    expect(r.alerts.single.changedFields, ['cgpa']);

    final items = syncAlerts(r.alerts);
    expect(items.single.text, contains('cgpa'));
    expect(r.alerts.single.urgency, isNot(Urgency.low));
    expect(items.single.paperId, isNull); // cannot say which copy is right
  });

  test('a reformatted copy raises nothing', () async {
    await a.syncNow([marksheet('8.74', id: 'x')]);
    final r = await b.syncNow([marksheet('8.740', id: 'y')]);
    expect(r.alerts, isEmpty);
  });

  test('nothing readable is sent to the relay', () async {
    await a.syncNow([marksheet('8.74')]);
    final all = sent.join();
    for (final plain in ['cgpa', '8.74', 'Asha', 'S482913', 'marksheet']) {
      expect(all.contains(plain), isFalse, reason: plain);
    }
  });

  test('a damaged code is refused and unpaired devices cannot sync', () async {
    final c = SyncService(store: MemoryPinStore());
    await c.load();
    expect(() => c.join('dv1:not-a-code'), throwsFormatException);
    expect(c.isPaired, isFalse);
    expect(() => c.syncNow([]), throwsStateError);
  });

  test('pairing survives a restart', () async {
    final store = MemoryPinStore();
    final first = SyncService(store: store);
    await first.load();
    final s = await first.secretOrCreate();
    final id = first.deviceId;
    final again = SyncService(store: store);
    await again.load();
    expect(again.secret!.key, s.key);
    expect(again.deviceId, id);
  });
}
