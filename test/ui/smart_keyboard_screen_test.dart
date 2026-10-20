import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/keyboard/smart_keyboard_screen.dart';

class _MockTTS implements TTSEngine {
  String? lastSpoken;
  @override
  Future<void> speak(String text, {required Locale locale}) async {
    lastSpoken = text;
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    lastSpoken = texts.join(' ');
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async => true;
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> setPitch(double pitch) async {}
}

void main() {
  testWidgets('SmartKeyboardScreen loads and types characters', (tester) async {
    final mockTts = _MockTTS();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsEngineProvider.overrideWithValue(mockTts),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SmartKeyboardScreen(initialText: 'Hello'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial text
    expect(find.text('Hello'), findsOneWidget);

    // Tap Speak button
    final speakBtn = find.text('Speak');
    expect(speakBtn, findsOneWidget);
    await tester.tap(speakBtn);
    await tester.pumpAndSettle();

    expect(mockTts.lastSpoken, equals('Hello'));

    // Tap backspace
    final backspaceBtn = find.byTooltip('Backspace');
    expect(backspaceBtn, findsOneWidget);
    await tester.tap(backspaceBtn);
    await tester.pumpAndSettle();

    expect(find.text('Hell'), findsOneWidget);

    // Switch to Arabic layout
    final arPill = find.text('AR');
    expect(arPill, findsOneWidget);
    await tester.tap(arPill);
    await tester.pumpAndSettle();

    // Arabic letters should now be visible on the on-screen keyboard
    expect(find.text('ض'), findsWidgets);
  });
}
