import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/onboarding/onboarding.dart';

Widget _host(StubWifiSource stub) => ProviderScope(
      overrides: [wifiSourceProvider.overrideWith((ref) => stub)],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: [Locale('en')],
        home: WifiContextScreen(),
      ),
    );

void main() {
  testWidgets(
      'Allow requests the permission exactly once and shows the granted state '
      '(ADR 0016: the only request site, not the tap path)', (tester) async {
    final stub = StubWifiSource(permissionGranted: true);
    await tester.pumpWidget(_host(stub));
    await tester.pumpAndSettle();

    expect(find.text('Allow'), findsOneWidget);
    await tester.ensureVisible(find.text('Allow'));
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(stub.requestCount, 1);
    expect(
      find.text('On. Lighthouse will learn words for each place.'),
      findsOneWidget,
    );
    // The button is replaced by the status row, so a second tap is impossible.
    expect(find.text('Allow'), findsNothing);
  });

  testWidgets('Declining shows the not-now guidance and still asks only once',
      (tester) async {
    final stub = StubWifiSource(permissionGranted: false);
    await tester.pumpWidget(_host(stub));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Allow'));
    await tester.tap(find.text('Allow'));
    await tester.pumpAndSettle();

    expect(stub.requestCount, 1);
    expect(
      find.text('Not now. You can turn this on later in Settings.'),
      findsOneWidget,
    );
  });
}
