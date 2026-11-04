import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the PIN record lives. Real runs use the platform's secure storage;
/// tests and the first frame before start-up finishes use memory.
abstract class PinStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryPinStore implements PinStore {
  final _m = <String, String>{};

  @override
  Future<String?> read(String key) async => _m[key];

  @override
  Future<void> write(String key, String value) async => _m[key] = value;
}

class SecurePinStore implements PinStore {
  static const _s = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
}

enum UnlockResult { ok, wrong, lockedOut }

/// The vault's PIN: stored only as a salted PBKDF2 hash, with a growing wait
/// after repeated wrong tries.
///
/// This locks the app. It does not yet encrypt the vault's database, and a
/// 6-digit PIN alone could not protect stolen files from an offline guess.
class PinLock {
  PinLock._();

  static const _recordKey = 'docuveil_pin';
  static const iterations = 100000;
  static const freeTries = 5;

  static PinStore store = MemoryPinStore();
  static Map<String, dynamic>? _record;

  /// False until the correct PIN is entered in this run of the app.
  static bool unlocked = false;

  static bool get isSet => _record?['hash'] != null;

  /// Read the stored record. Call once at start-up.
  static Future<void> load(PinStore s) async {
    store = s;
    final raw = await s.read(_recordKey);
    _record = raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    unlocked = false;
  }

  /// PBKDF2-HMAC-SHA256 with one output block (32 bytes).
  static List<int> derive(String pin, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = List<int>.of(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static Future<void> _save() => store.write(_recordKey, jsonEncode(_record));

  /// Set a new PIN and unlock.
  static Future<void> setPin(String pin, {int rounds = iterations}) async {
    final r = Random.secure();
    final salt = [for (var i = 0; i < 16; i++) r.nextInt(256)];
    _record = {
      'salt': base64.encode(salt),
      'hash': base64.encode(derive(pin, salt, rounds)),
      'rounds': rounds,
      'wrong': 0,
      'lockedUntil': 0,
    };
    await _save();
    unlocked = true;
  }

  /// Seconds left before another try is allowed.
  static int waitSeconds([DateTime? now]) {
    final until = (_record?['lockedUntil'] as int?) ?? 0;
    final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return until <= t ? 0 : ((until - t) / 1000).ceil();
  }

  static Future<UnlockResult> tryPin(String pin, {DateTime? now}) async {
    if (waitSeconds(now) > 0) return UnlockResult.lockedOut;
    final rec = _record!;
    final got = derive(
      pin,
      base64.decode(rec['salt'] as String),
      rec['rounds'] as int,
    );
    final want = base64.decode(rec['hash'] as String);
    var diff = got.length ^ want.length;
    for (var i = 0; i < got.length && i < want.length; i++) {
      diff |= got[i] ^ want[i];
    }
    if (diff == 0) {
      rec['wrong'] = 0;
      rec['lockedUntil'] = 0;
      await _save();
      unlocked = true;
      return UnlockResult.ok;
    }
    final wrong = (rec['wrong'] as int) + 1;
    rec['wrong'] = wrong;
    if (wrong >= freeTries) {
      // 30 s, 1 min, 2 min ... at most one hour.
      final secs = min(3600, 30 * (1 << min(wrong - freeTries, 7)));
      final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
      rec['lockedUntil'] = t + secs * 1000;
    }
    await _save();
    return UnlockResult.wrong;
  }

  static void lock() => unlocked = false;

  /// Forget the record. For tests.
  static void reset() {
    _record = null;
    unlocked = false;
    store = MemoryPinStore();
  }
}
