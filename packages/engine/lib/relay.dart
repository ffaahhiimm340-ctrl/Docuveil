/// HTTP client for the relay server (server/). Kept out of the main library
/// so `docuveil_engine.dart` stays free of network code.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'docuveil_engine.dart';

class RelayException implements Exception {
  RelayException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'RelayException($statusCode): $body';
}

/// One device's connection to the relay. [deviceId] is visible to the
/// server, so use a random id, not a name like "Asha's phone".
class RelayClient {
  RelayClient(
    this.baseUrl,
    this.secret,
    this.deviceId, {
    http.Client? client,
  }) : _http = client ?? http.Client();

  final Uri baseUrl;
  final PairingSecret secret;
  final String deviceId;
  final http.Client _http;

  Uri _url(String path, [Map<String, String>? query]) => baseUrl.replace(
    path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}/v1/${secret.ownerToken}/$path',
    queryParameters: query,
  );

  /// Send this device's fingerprint of a document. Returns the relay's
  /// sequence number for it.
  Future<int> push(FingerprintSet fp) async {
    final res = await _http.post(
      _url('fingerprints'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'device_id': deviceId, ...fp.toJson()}),
    );
    if (res.statusCode != 200) throw RelayException(res.statusCode, res.body);
    return (jsonDecode(res.body) as Map<String, dynamic>)['seq'] as int;
  }

  /// Fingerprints the owner's other devices sent after [since].
  Future<List<RemoteEntry>> pull({int since = 0}) async {
    final res = await _http.get(
      _url('changes', {'device_id': deviceId, 'since': '$since'}),
    );
    if (res.statusCode != 200) throw RelayException(res.statusCode, res.body);
    final list = (jsonDecode(res.body) as Map<String, dynamic>)['changes'] as List;
    return [
      for (final e in list) RemoteEntry.fromJson(e as Map<String, dynamic>),
    ];
  }

  void close() => _http.close();
}
