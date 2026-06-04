import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/settings/about_screen.dart';
import 'package:lighthouse/ui/settings/math_gate.dart';

import '../../support/localized.dart';

void main() {
  testWidgets('shows KHF attribution and app name', (tester) async {
    await tester.pumpWidget(localizedApp(const AboutScreen()));
    await tester.pump();
    expect(find.text('Lighthouse AAC'), findsOneWidget);
    expect(
      find.text('A free project of the Kinder Horizon Foundation.'),
      findsOneWidget,
    );
  });

  testWidgets('the website link is gated behind the math gate',
      (tester) async {
    await tester.pumpWidget(localizedApp(const AboutScreen()));
    await tester.pump();

    expect(find.text('Visit kinderhorizon.org'), findsOneWidget);
    await tester.tap(find.text('Visit kinderhorizon.org'));
    await tester.pumpAndSettle();

    // Tapping the link must present the math gate, not launch directly.
    expect(find.byType(MathGate), findsOneWidget);
  });

  testWidgets('contains NO in-app donation/support wording (store rule)',
      (tester) async {
    // App Store / child-audience compliance: the in-app copy must stay
    // neutral. The donation ask lives only on the website. If a future
    // edit adds "Donate" / "Support" / "Give" wording in-app, this fails
    // on purpose.
    await tester.pumpWidget(localizedApp(const AboutScreen()));
    await tester.pump();

    for (final banned in ['Donate', 'donate', 'Support', 'support', 'Give']) {
      expect(find.textContaining(banned), findsNothing,
          reason: 'in-app About copy must not contain "$banned"');
    }
  });
}
