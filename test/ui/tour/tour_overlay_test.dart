/// Tour overlay: shows the current step's caption card, Next advances, Skip
/// ends (ADR 0020).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/ui/tour/tour_controller.dart';
import 'package:lighthouse/ui/tour/tour_overlay.dart';

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: Scaffold(body: TourOverlay()),
      ),
    );

void main() {
  testWidgets('renders nothing while inactive', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tour_next')), findsNothing);
  });

  testWidgets('shows step 1, Next advances, Skip ends', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));

    c.read(tourControllerProvider.notifier).start();
    await tester.pumpAndSettle();

    expect(find.text('1 OF 7'), findsOneWidget);
    expect(find.text("This is your child's board"), findsOneWidget);
    // First step: no Back button.
    expect(find.byKey(const ValueKey('tour_back')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tour_next')));
    await tester.pumpAndSettle();
    expect(find.text('2 OF 7'), findsOneWidget);
    expect(find.byKey(const ValueKey('tour_back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tour_skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tour_next')), findsNothing);
    expect(c.read(tourControllerProvider).active, isFalse);
  });
}
