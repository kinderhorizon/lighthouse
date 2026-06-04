/// Onboarding privacy explainer (ADR 0003 + ADR 0017/0018 reconciliation).
///
/// In the shipped (default) build both OTA and feedback endpoints are unset, so
/// the explainer must NOT describe those egress paths: the copy can only claim a
/// data path the build can actually take. This pins the gated-off state (the
/// only one testable without flipping the compile-time config consts).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/onboarding/screens/privacy_claim_screen.dart';

import '../../support/localized.dart';

void main() {
  testWidgets('explainer hides update/feedback egress copy when unconfigured',
      (tester) async {
    await tester.pumpWidget(localizedApp(const PrivacyClaimScreen()));
    await tester.pump();

    // Open the "How we know" explainer.
    await tester.tap(find.byTooltip('How we know this is true'));
    await tester.pumpAndSettle();

    expect(find.text('How we know'), findsOneWidget);
    // The core no-cloud claim is present...
    expect(find.textContaining('does not connect to any cloud'), findsOneWidget);
    // ...but the OTA / feedback egress sentences are NOT, because neither
    // endpoint is configured in this build.
    expect(find.textContaining('Check for updates'), findsNothing);
    expect(find.textContaining('Send feedback'), findsNothing);
  });
}
