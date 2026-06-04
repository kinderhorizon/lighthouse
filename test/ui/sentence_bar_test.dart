/// Sentence bar widget (ADR 0010).
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/l10n/app_localizations.dart';
import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';

class _RecordingTTSEngine implements TTSEngine {
  final List<({String text, Locale locale})> calls = [];
  final List<List<String>> sequences = [];

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    calls.add((text: text, locale: locale));
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    sequences.add(texts);
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

AACButton _verb(String word, {String iconUri = ''}) => AACButton.fromJson({
      'id': 'btn_$word',
      'label': word,
      'type': 'word',
      'voice_out': word,
      'position': {'row': 0, 'col': 0},
      'category': 'verb',
      if (iconUri.isNotEmpty) 'icon_uri': iconUri,
    });

Widget _host(
  ProviderContainer container, {
  bool hideText = false,
  bool hideIcon = false,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: SentenceBar(hideText: hideText, hideIcon: hideIcon)),
    ),
  );
}

void main() {
  late ProviderContainer container;
  late _RecordingTTSEngine fakeTts;
  late ContextManager cm;

  setUp(() {
    fakeTts = _RecordingTTSEngine();
    cm = ContextManager();
    container = ProviderContainer(
      overrides: [
        ttsEngineProvider.overrideWith((ref) => fakeTts),
        contextManagerProvider.overrideWithValue(cm),
      ],
    );
  });
  tearDown(() => container.dispose());

  testWidgets('empty bar shows the hint and speaks nothing', (tester) async {
    await tester.pumpWidget(_host(container));
    await tester.pumpAndSettle();

    expect(find.text('Tap words to build a sentence'), findsOneWidget);

    // Speak control is present but disabled: tapping it does nothing.
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();
    expect(fakeTts.sequences, isEmpty);
  });

  testWidgets('tokens render as chips and speak the composed sentence',
      (tester) async {
    await tester.pumpWidget(_host(container));
    container.read(utteranceProvider.notifier).append(_verb('want'));
    container.read(utteranceProvider.notifier).append(_verb('go'));
    await tester.pump();

    // Chips show the (non-localized) labels.
    expect(find.text('want'), findsOneWidget);
    expect(find.text('go'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();

    // Replay hands the engine the ordered word list (so it can concatenate
    // per-word clips), with the English "to" inserted between the two verbs
    // (item #7, ADR 0010).
    expect(fakeTts.sequences, hasLength(1));
    expect(fakeTts.sequences.single, ['want', 'to', 'go']);

    // Auto-clear after speak (the clinical lead): the bar resets once playback ends.
    await tester.pump();
    expect(find.text('want'), findsNothing);
    expect(find.text('go'), findsNothing);
    expect(find.text('Tap words to build a sentence'), findsOneWidget);
  });

  testWidgets('backspace removes the last token, clear empties', (tester) async {
    await tester.pumpWidget(_host(container));
    container.read(utteranceProvider.notifier).append(_verb('want'));
    container.read(utteranceProvider.notifier).append(_verb('go'));
    await tester.pump();

    await tester.tap(find.byTooltip('Remove last word'));
    await tester.pump();
    expect(find.text('go'), findsNothing);
    expect(find.text('want'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear sentence'));
    await tester.pump();
    expect(find.text('want'), findsNothing);
    expect(find.text('Tap words to build a sentence'), findsOneWidget);
  });

  testWidgets(
      'backspace rewinds the bandit context to the remaining word + bumps the '
      'glow epoch', (tester) async {
    await tester.pumpWidget(_host(container));
    // Simulate tapping Eat then Apple: the bar and the context both advance
    // (in the app, the tap handler appends AND records the tap).
    final eat = _verb('eat');
    final apple = _verb('apple');
    container.read(utteranceProvider.notifier)
      ..append(eat)
      ..append(apple);
    cm
      ..recordTap(eat)
      ..recordTap(apple);
    await tester.pump();
    expect(cm.previousButtonId, 'btn_apple');
    final epochBefore = container.read(contextEpochProvider);

    await tester.tap(find.byTooltip('Remove last word'));
    // The revert is enqueued on the shared tap queue (async); let it drain.
    await tester.pumpAndSettle();

    // The deleted word no longer drives prediction: context follows the bar.
    expect(cm.previousButtonId, 'btn_eat');
    // The glow was invalidated so the bandit re-predicts under the new context.
    expect(container.read(contextEpochProvider), greaterThan(epochBefore));
  });

  testWidgets('clear rewinds the context to sentence start + bumps the epoch',
      (tester) async {
    await tester.pumpWidget(_host(container));
    final eat = _verb('eat');
    container.read(utteranceProvider.notifier).append(eat);
    cm.recordTap(eat);
    await tester.pump();
    expect(cm.previousButtonId, 'btn_eat');
    final epochBefore = container.read(contextEpochProvider);

    await tester.tap(find.byTooltip('Clear sentence'));
    await tester.pumpAndSettle(); // revert is enqueued on the shared queue

    expect(cm.previousButtonId, isNull); // sentence start
    expect(container.read(contextEpochProvider), greaterThan(epochBefore));
  });

  testWidgets('word-only mode (hideIcon) drops the chip pictogram, keeps text',
      (tester) async {
    await tester.pumpWidget(_host(container, hideIcon: true));
    container.read(utteranceProvider.notifier).append(
          _verb('want', iconUri: 'assets/arasaac/verbs/want.png'),
        );
    await tester.pump();
    expect(find.text('want'), findsOneWidget);
    expect(find.byType(Image), findsNothing,
        reason: 'word-only mode must drop the chip pictogram');
  });

  testWidgets('picture-only mode (hideText) drops the chip label, keeps icon',
      (tester) async {
    await tester.pumpWidget(_host(container, hideText: true));
    container.read(utteranceProvider.notifier).append(
          _verb('want', iconUri: 'assets/arasaac/verbs/want.png'),
        );
    await tester.pump();
    expect(find.text('want'), findsNothing);
    expect(find.byType(Image), findsOneWidget,
        reason: 'picture-only mode keeps the chip pictogram');
  });
}
