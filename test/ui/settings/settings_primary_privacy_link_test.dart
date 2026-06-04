/// Dead-UI gate for the hosted privacy-policy link (item 3 of the privacy
/// plumbing). The "Privacy policy" entry must stay hidden until a policy URL
/// is baked in (the page is published), so a parent never taps a link that
/// 404s. Same enforcement intent as the OTA / feedback tile gates.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/settings/settings_primary_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localized.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  testWidgets('Privacy policy tile is hidden while the URL const is empty',
      (tester) async {
    // The default build leaves the policy URL empty until the hosted page is
    // live; the launch build sets it via --dart-define=PRIVACY_POLICY_URL.
    expect(kLighthousePrivacyPolicyUrl, isEmpty);

    // Tall viewport so the whole list (down to the About section, where the
    // privacy entry would sit) lays out and builds its rows.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(child: localizedApp(const SettingsPrimaryScreen())),
    );
    await tester.pumpAndSettle();

    // The About section rendered (proves the list reached the bottom)...
    expect(find.text('About Lighthouse'), findsOneWidget);
    // ...but the gated privacy-policy entry is absent from the tree.
    expect(find.text('Privacy policy'), findsNothing);
  });

  testWidgets('Privacy policy tile appears once a URL is configured',
      (tester) async {
    // Configured-on state: a launch build sets PRIVACY_POLICY_URL, which the
    // provider surfaces. Overriding the provider exercises that path without a
    // build-time define. We assert visibility (the dead-UI gate's positive
    // case); the tap opens an external browser via url_launcher, which is a
    // platform call not driven in a widget test.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyPolicyUrlProvider.overrideWithValue(
            'https://kinderhorizon.org/lighthouse/privacy',
          ),
        ],
        child: localizedApp(const SettingsPrimaryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Privacy policy'), findsOneWidget);
  });
}
