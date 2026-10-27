import 'dart:convert';
import 'dart:math';

import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:docuveil_engine/relay.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('pairing', () {
    test('code round-trips and both devices get the same key and token', () {
      final a = PairingSecret.generate(Random(1));
      final b = PairingSecret.decode(a.encode());
      expect(b.key, a.key);
      expect(b.ownerToken, a.ownerToken);
      expect(a.encode(), startsWith('dv1:'));
    });

    test('a mistyped code is rejected, not silently accepted', () {
      final code = PairingSecret.generate(Random(2)).encode();
      final i = code.length - 10;
      final bad = code.replaceRange(i, i + 1, code[i] == 'A' ? 'B' : 'A');
      expect(() => PairingSecret.decode(bad), throwsFormatException);
      expect(() => PairingSecret.decode('hello'), throwsFormatException);
      expect(() => PairingSecret.decode('dv1:abc'), throwsFormatException);
    });

    test('owner token does not contain the key and differs per owner', () {
      final a = PairingSecret.generate(Random(3));
      final b = PairingSecret.generate(Random(4));
      expect(a.ownerToken, hasLength(32));
      expect(a.ownerToken, isNot(b.ownerToken));
      final keyHex = a.key.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      expect(keyHex.contains(a.ownerToken), isFalse);
    });
  });

  group('relay client', () {
    final secret = PairingSecret.generate(Random(5));
    final doc = ExtractedDoc(
      id: 'm1',
      type: DocType.marksheet,
      fields: {'name': 'Rahul', 'cgpa': '8.74'},
    );

    test('push sends only tags under the owner token', () async {
      late http.Request sent;
      final client = RelayClient(
        Uri.parse('http://relay.test'),
        secret,
        'dev-a',
        client: MockClient((req) async {
          sent = req;
          return http.Response('{"seq": 7}', 200);
        }),
      );
      final seq = await client.push(fingerprint(secret.key, doc));
      expect(seq, 7);
      expect(sent.url.path, '/v1/${secret.ownerToken}/fingerprints');
      expect(sent.body.contains('cgpa'), isFalse);
      expect(sent.body.contains('8.74'), isFalse);
      expect(sent.body.contains('Rahul'), isFalse);
      expect((jsonDecode(sent.body) as Map)['device_id'], 'dev-a');
    });

    test('pull parses entries that detectDivergence can use', () async {
      final theirs = fingerprint(secret.key, ExtractedDoc(
        id: 'm1',
        type: DocType.marksheet,
        fields: {'name': 'Rahul', 'cgpa': '9.40'},
      ));
      final client = RelayClient(
        Uri.parse('http://relay.test/base/'),
        secret,
        'dev-a',
        client: MockClient((req) async {
          expect(req.url.path, '/base/v1/${secret.ownerToken}/changes');
          expect(req.url.queryParameters, {'device_id': 'dev-a', 'since': '3'});
          return http.Response(
            jsonEncode({
              'changes': [
                {'seq': 4, 'ts': 0.0, 'device_id': 'dev-b', ...theirs.toJson()},
              ],
            }),
            200,
          );
        }),
      );
      final entries = await client.pull(since: 3);
      final mine = fingerprint(secret.key, doc);
      final alerts = detectDivergence(
        secret.key,
        local: {mine.docTag: mine},
        remote: entries,
        knownFields: doc.fields.keys,
        availability: (_) => const AvailabilityInput(copies: 1),
      );
      expect(alerts.single.changedFields, ['cgpa']);
      expect(alerts.single.remoteDevice, 'dev-b');
    });

    test('server errors surface as RelayException', () async {
      final client = RelayClient(
        Uri.parse('http://relay.test'),
        secret,
        'dev-a',
        client: MockClient((_) async => http.Response('bad', 422)),
      );
      expect(client.pull(), throwsA(isA<RelayException>()));
    });
  });
}
