import 'dart:math';

import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:docuveil_engine/relay.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'intake.dart' show expectedFields;
import 'pin_lock.dart' show MemoryPinStore, PinStore;
import 'vault.dart';

/// Names one paper across devices, whatever the bytes of each copy: its type
/// plus its own number. Limitation: an edit to that number itself makes the
/// copy look like a different paper, so it is not reported by sync.
String paperKey(ExtractedDoc d) {
  for (final k in const ['id_number', 'policy_number', 'seat_number', 'name']) {
    final v = d.fields[k];
    if (v != null && v.trim().isNotEmpty) {
      return '${d.type.name}|${normalizeField(k, v)}';
    }
  }
  return '${d.type.name}|${d.id}';
}

class SyncResult {
  const SyncResult(this.pushed, this.alerts);

  final int pushed;
  final List<DivergenceAlert> alerts;
}

/// This device's link to the owner's other devices through the relay. Only
/// keyed fingerprints leave the device (see engine fingerprint.dart).
class SyncService {
  SyncService({PinStore? store, this.client})
    : _store = store ?? MemoryPinStore();

  static const _keySecret = 'docuveil_pairing';
  static const _keyDevice = 'docuveil_device_id';
  static const _keyRelay = 'docuveil_relay_url';

  /// The app's instance; start-up replaces it with one on secure storage.
  static SyncService instance = SyncService();

  final PinStore _store;
  final http.Client? client;

  PairingSecret? secret;
  String deviceId = '';
  String relayUrl = '';
  int _since = 0;
  final Map<String, RemoteEntry> _seen = {};

  /// Newest alerts, for the Alerts screen. Doc tag -> vault paper id is in
  /// [paperIds].
  final alerts = ValueNotifier<List<DivergenceAlert>>(const []);
  final paperIds = <String, String>{};

  bool get isPaired => secret != null;

  Future<void> load() async {
    final code = await _store.read(_keySecret);
    secret = code == null ? null : PairingSecret.decode(code);
    relayUrl = await _store.read(_keyRelay) ?? '';
    deviceId = await _store.read(_keyDevice) ?? '';
    if (deviceId.isEmpty) {
      // Random, so the relay does not learn a name like "Asha's phone".
      final r = Random.secure();
      deviceId = 'dev-${List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join()}';
      await _store.write(_keyDevice, deviceId);
    }
  }

  /// The secret to show as a QR code, created the first time.
  Future<PairingSecret> secretOrCreate() async {
    final existing = secret;
    if (existing != null) return existing;
    final s = PairingSecret.generate();
    await _store.write(_keySecret, s.encode());
    return secret = s;
  }

  /// Join the owner's other devices with a code from one of them. Throws
  /// [FormatException] for a damaged code.
  Future<void> join(String code) async {
    final s = PairingSecret.decode(code);
    await _store.write(_keySecret, s.encode());
    secret = s;
    _since = 0;
    _seen.clear();
  }

  Future<void> setRelayUrl(String url) async {
    relayUrl = url.trim();
    await _store.write(_keyRelay, relayUrl);
  }

  /// Send this device's fingerprints, fetch the others', and compare.
  Future<SyncResult> syncNow(List<VaultDoc> docs) async {
    final s = secret;
    if (s == null) throw StateError('This device is not paired yet.');
    if (relayUrl.isEmpty) throw StateError('No relay address set.');
    final relay = RelayClient(
      Uri.parse(relayUrl),
      s,
      deviceId,
      client: client,
    );
    final local = <String, FingerprintSet>{};
    final fields = <String>{};
    final docOf = <String, VaultDoc>{};
    for (final v in docs) {
      final fp = fingerprint(
        s.key,
        ExtractedDoc(
          id: paperKey(v.doc),
          type: v.doc.type,
          fields: v.doc.fields,
        ),
      );
      local[fp.docTag] = fp;
      docOf[fp.docTag] = v;
      paperIds[fp.docTag] = v.doc.id;
      fields
        ..addAll(v.doc.fields.keys)
        ..addAll(expectedFields[v.doc.type] ?? const []);
      await relay.push(fp);
    }
    for (final e in await relay.pull(since: _since)) {
      _since = max(_since, e.seq);
      _seen['${e.deviceId}|${e.fingerprint.docTag}'] = e;
    }
    final found = detectDivergence(
      s.key,
      local: local,
      remote: _seen.values,
      knownFields: fields,
      availability: (tag) => const AvailabilityInput(copies: 2),
    );
    alerts.value = found;
    return SyncResult(local.length, found);
  }
}
