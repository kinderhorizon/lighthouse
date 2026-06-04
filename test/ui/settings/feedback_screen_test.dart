/// "Send feedback" screen (ADR 0018).
///
/// Drives the form through a MockClient-backed FeedbackClient so no real
/// network is touched. Asserts the UI contract: an empty message is caught
/// before any POST; a valid Send posts ONLY the declared fields (no child /
/// board / usage data) and then thanks the parent; a server failure keeps the
/// typed draft and surfaces a retry message.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/settings/feedback_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _endpoint = 'https://feedback.example/submit';

Widget _host(FeedbackClient client) {
  return ProviderScope(
    overrides: [
      feedbackClientProvider.overrideWithValue(client),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: [Locale('en')],
      home: FeedbackScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Lighthouse',
      packageName: 'org.kinderhorizon.lighthouse',
      version: '1.2.3',
      buildNumber: '7',
      buildSignature: '',
    );
  });

  testWidgets('empty message is caught before any network call',
      (tester) async {
    var posted = false;
    final client = FeedbackClient(
      endpointUrl: _endpoint,
      client: MockClient((req) async {
        posted = true;
        return http.Response('', 202);
      }),
    );
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(client));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('feedback_send')));
    await tester.pumpAndSettle();

    expect(posted, isFalse);
    expect(find.text('Please write a message first.'), findsOneWidget);
  });

  testWidgets('valid send posts only declared fields, then thanks the parent',
      (tester) async {
    late http.Request captured;
    final client = FeedbackClient(
      endpointUrl: _endpoint,
      client: MockClient((req) async {
        captured = req;
        return http.Response('', 202);
      }),
    );
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(client));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('feedback_message')), 'The voice is wrong');
    await tester.tap(find.byKey(const ValueKey('feedback_send')));
    await tester.pumpAndSettle();

    // Thanked, and the POST carried only the declared, low-entropy fields.
    expect(find.text('Thank you. Your message is on its way.'), findsOneWidget);
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['category'], 'bug');
    expect(body['message'], 'The voice is wrong');
    expect(body['appVersion'], '1.2.3');
    expect(body.containsKey('osVersion'), isTrue);
    expect(body.containsKey('locale'), isTrue);
    expect(body.containsKey('clientNonce'), isTrue);
    // No child / board / usage / device-identifier fields ever leave the app.
    for (final banned in ['childName', 'boardId', 'usage', 'deviceId']) {
      expect(body.containsKey(banned), isFalse, reason: 'leaked $banned');
    }
  });

  testWidgets('server failure keeps the draft and shows a retry message',
      (tester) async {
    final client = FeedbackClient(
      endpointUrl: _endpoint,
      client: MockClient((req) async => http.Response('', 500)),
    );
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(client));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('feedback_message')), 'Crashes on launch');
    await tester.tap(find.byKey(const ValueKey('feedback_send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not send right now'), findsOneWidget);
    // The typed message is preserved so the parent can retry.
    expect(find.text('Crashes on launch'), findsOneWidget);
  });
}
