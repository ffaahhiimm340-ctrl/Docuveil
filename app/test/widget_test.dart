import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:docuveil/main.dart';

void main() {
  setUpAll(() {
    // Tests run offline: use fallback fonts instead of downloading.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('app starts on the welcome screen', (tester) async {
    await tester.pumpWidget(const DocuveilApp());
    await tester.pumpAndSettle();
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('PIN opens the vault and Home shows the change alert', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const DocuveilApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('I already have a vault'));
    await tester.pumpAndSettle();
    for (final d in '123456'.split('')) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('1 thing needs you'), findsOneWidget);
    expect(find.text('See what changed'), findsOneWidget);
  });
}
