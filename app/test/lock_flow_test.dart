import 'package:docuveil/data/pin_lock.dart';
import 'package:docuveil/main.dart';
import 'package:docuveil/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> enter(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('set a PIN, lock, blocked from pages, wrong PIN, right PIN', (t) async {
    await t.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    PinLock.reset();
    await t.pumpWidget(const DocuveilApp());
    await t.pumpAndSettle();

    // Two different PINs: asked to start again, nothing stored.
    appRouter.go('/setup-lock');
    await t.pumpAndSettle();
    await enter(t, '111111');
    expect(find.text('Enter the same PIN again'), findsOneWidget);
    await enter(t, '222222');
    expect(find.textContaining('did not match'), findsOneWidget);
    expect(PinLock.isSet, isFalse);

    // Matching PINs: stored, and into the app.
    await enter(t, '123456');
    await t.runAsync(() async {
      await enter(t, '123456');
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await t.pumpAndSettle();
    expect(PinLock.isSet, isTrue);
    expect(find.text('Your papers'), findsOneWidget);

    // Locked: every page sends you to the PIN screen.
    PinLock.lock();
    appRouter.go('/papers');
    await t.pumpAndSettle();
    expect(find.text('Enter your PIN to open your vault.'), findsOneWidget);

    // Wrong PIN: stays locked, with a message.
    await t.runAsync(() async {
      await enter(t, '999999');
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await t.pumpAndSettle();
    expect(find.textContaining('not right'), findsOneWidget);
    expect(PinLock.unlocked, isFalse);

    // Right PIN: in.
    await t.runAsync(() async {
      await enter(t, '123456');
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await t.pumpAndSettle();
    expect(PinLock.unlocked, isTrue);
    expect(find.text('Your papers'), findsOneWidget);
    PinLock.reset();
  });
}
