import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/settings/profiles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProfilesScreen lists profiles and allows creating a new profile',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfilesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('User Profiles'), findsOneWidget);
    expect(find.text('Default User'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);

    // Tap Add New Profile
    final addBtn = find.text('Add New Profile');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('Create Profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Maya');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Maya'), findsOneWidget);
  });
}
