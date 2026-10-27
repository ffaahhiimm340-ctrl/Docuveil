import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// The secret an owner's devices share. Created on the first device and
/// carried to the others by the pairing QR code; it never reaches the relay.
///
/// Only [key] travels. The owner token the relay sees is derived from it with
/// HMAC, so the server gets a stable mailbox name that it cannot turn back
/// into the key, and two owners never collide.
class PairingSecret {
  PairingSecret(List<int> key) : key = List.unmodifiable(key) {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'must be 32 bytes');
    }
  }

  /// A fresh secret from the platform's secure random source.
  factory PairingSecret.generate([Random? random]) {
    final r = random ?? Random.secure();
    return PairingSecret([for (var i = 0; i < 32; i++) r.nextInt(256)]);
  }

  static const _prefix = 'dv1:';

  /// HMAC-SHA256 key for fingerprints (see fingerprint.dart).
  final List<int> key;

  /// Relay mailbox name: 32 hex characters, not reversible to [key].
  String get ownerToken => Hmac(
    sha256,
    key,
  ).convert(utf8.encode('docuveil owner token')).toString().substring(0, 32);

  /// Text for the pairing QR code: prefix, key, 4-byte checksum.
  String encode() {
    final check = sha256.convert(key).bytes.sublist(0, 4);
    return _prefix + base64Url.encode([...key, ...check]).replaceAll('=', '');
  }

  /// Reads a code made by [encode]. Throws [FormatException] if it is not a
  /// Docuveil code or was mistyped / damaged (checksum mismatch).
  static PairingSecret decode(String code) {
    final t = code.trim();
    if (!t.startsWith(_prefix)) {
      throw const FormatException('Not a Docuveil pairing code');
    }
    var body = t.substring(_prefix.length);
    body += '=' * ((4 - body.length % 4) % 4);
    final List<int> bytes;
    try {
      bytes = base64Url.decode(body);
    } on FormatException {
      throw const FormatException('Pairing code is damaged');
    }
    if (bytes.length != 36) {
      throw const FormatException('Pairing code is the wrong length');
    }
    final key = bytes.sublist(0, 32);
    final check = sha256.convert(key).bytes.sublist(0, 4);
    for (var i = 0; i < 4; i++) {
      if (check[i] != bytes[32 + i]) {
        throw const FormatException('Pairing code is damaged');
      }
    }
    return PairingSecret(key);
  }
}
