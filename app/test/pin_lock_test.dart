import 'package:docuveil/data/pin_lock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const rounds = 10; // real runs use 100,000; tests only check the logic
  setUp(PinLock.reset);

  test('the right PIN opens, a wrong one does not, nothing is stored in clear', () async {
    final store = MemoryPinStore();
    await PinLock.load(store);
    expect(PinLock.isSet, isFalse);
    await PinLock.setPin('482913', rounds: rounds);
    expect((await store.read('docuveil_pin'))!.contains('482913'), isFalse);

    await PinLock.load(store); // as after restarting the app
    expect(PinLock.isSet, isTrue);
    expect(PinLock.unlocked, isFalse);
    expect(await PinLock.tryPin('000000'), UnlockResult.wrong);
    expect(PinLock.unlocked, isFalse);
    expect(await PinLock.tryPin('482913'), UnlockResult.ok);
    expect(PinLock.unlocked, isTrue);
  });

  test('two vaults with the same PIN store different hashes', () async {
    final a = MemoryPinStore(), b = MemoryPinStore();
    await PinLock.load(a);
    await PinLock.setPin('111111', rounds: rounds);
    await PinLock.load(b);
    await PinLock.setPin('111111', rounds: rounds);
    expect(await a.read('docuveil_pin'), isNot(await b.read('docuveil_pin')));
  });

  test('PBKDF2 matches a published test vector', () {
    // RFC 7914 section 11: PBKDF2-HMAC-SHA256, "passwd", "salt", 1 round.
    final out = PinLock.derive('passwd', 'salt'.codeUnits, 1);
    final hex = out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex, '55ac046e56e3089fec1691c22544b605f94185216dde0465e68b9d57c20dacbc');
  });

  test('repeated wrong tries make you wait, even with the right PIN', () async {
    await PinLock.load(MemoryPinStore());
    await PinLock.setPin('482913', rounds: rounds);
    final t0 = DateTime(2026, 11, 4, 10);
    for (var i = 0; i < PinLock.freeTries; i++) {
      expect(await PinLock.tryPin('000000', now: t0), UnlockResult.wrong);
    }
    expect(PinLock.waitSeconds(t0), 30);
    expect(await PinLock.tryPin('482913', now: t0), UnlockResult.lockedOut);
    final later = t0.add(const Duration(seconds: 31));
    expect(await PinLock.tryPin('482913', now: later), UnlockResult.ok);
    expect(PinLock.waitSeconds(later), 0);
  });
}
