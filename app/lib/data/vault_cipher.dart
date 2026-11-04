import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

import 'pin_lock.dart' show PinStore;

/// Encrypts vault records with AES-256-GCM.
///
/// The key lives in the platform's secure storage (Android Keystore, Windows
/// DPAPI), so a copied database file alone cannot be read. It is not derived
/// from the PIN: someone who can run code as the owner on the unlocked device
/// could still reach it. Row count and record sizes stay visible.
class VaultCipher {
  VaultCipher(this._key) {
    if (_key.length != 32) throw ArgumentError('Key must be 32 bytes');
  }

  /// A fresh random key, not stored anywhere. For tests.
  factory VaultCipher.random() => VaultCipher(_randomKey());

  static const _storeKey = 'docuveil_vault_key';

  final List<int> _key;
  static final _aes = AesGcm.with256bits();

  static List<int> _randomKey() {
    final r = Random.secure();
    return [for (var i = 0; i < 32; i++) r.nextInt(256)];
  }

  /// The device's key, created the first time.
  static Future<VaultCipher> loadOrCreate(PinStore store) async {
    final saved = await store.read(_storeKey);
    if (saved != null) return VaultCipher(base64.decode(saved));
    final key = _randomKey();
    await store.write(_storeKey, base64.encode(key));
    return VaultCipher(key);
  }

  /// Row name that does not reveal the paper's id or type.
  String rowName(String id) =>
      hash.Hmac(hash.sha256, _key).convert(utf8.encode('row|$id')).toString();

  /// Encrypt [plain]. [row] is bound to the result, so a record copied onto
  /// another row fails to open.
  Future<String> seal(String plain, String row) async {
    final box = await _aes.encrypt(
      utf8.encode(plain),
      secretKey: SecretKey(_key),
      aad: utf8.encode(row),
    );
    return base64.encode(box.concatenation());
  }

  /// Decrypt a record. Throws [SecretBoxAuthenticationError] if the key is
  /// wrong or the record was altered.
  Future<String> open(String sealed, String row) async {
    final box = SecretBox.fromConcatenation(
      base64.decode(sealed),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final plain = await _aes.decrypt(
      box,
      secretKey: SecretKey(_key),
      aad: utf8.encode(row),
    );
    return utf8.decode(plain);
  }
}
