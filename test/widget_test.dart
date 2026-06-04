import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lighthouse/logic/logic.dart';
import 'package:lighthouse/main.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/services/services.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';

class _RecordingTTSEngine implements TTSEngine {
  final List<({String text, Locale locale})> calls = [];

  @override
  Future<void> speak(String text, {required Locale locale}) async {
    calls.add((text: text, locale: locale));
  }

  @override
  Future<void> speakSequence(List<String> texts, {required Locale locale}) async {
    calls.add((text: texts.join(' '), locale: locale));
  }

  @override
  Future<bool> canSpeak(String text, {required Locale locale}) async => true;

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// Loads the board from the on-disk fixture (NOT through rootBundle) so the
/// widget tests don't depend on Flutter's asset machinery. The board_loader
/// integration test in test/services/board_loader_test.dart still covers
/// the rootBundle path for the real default board.
late final AACBoard _fixtureBoard;

AACBoard _loadFixtureBoard() {
  final file = File('test/fixtures/core_main.json');
  final raw = file.readAsStringSync();
  return AACBoard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

ProviderScope _wrap({
  required List<Override> extraOverrides,
}) {
  final crashStore = CrashLogStore(
    cacheDirOverride: Directory.systemTemp.createTempSync('widget_test_'),
  );
  final capture = CrashCapture(
    store: crashStore,
    deviceInfoSource: DeviceInfoSource(),
  );
  return ProviderScope(
    overrides: [
      defaultBoardProvider.overrideWith((ref) async => _fixtureBoard),
      crashLogStoreProvider.overrideWithValue(crashStore),
      crashCaptureProvider.overrideWithValue(capture),
      ...extraOverrides,
    ],
    child: const LighthouseApp(),
  );
}

Future<void> _settleInitial(WidgetTester tester) async {
  // These tests target the primary iPad (the board's fill layout). Pin a
  // large-tablet surface (1024pt shortest side) so the board does NOT fall into
  // the phone / small-tablet scroll tier (handoff Rule 3), where lower tiles
  // lazy-build offscreen and finders for Food / Bathroom would miss. Phone /
  // small-screen scroll behavior is covered in test/ui/board_size_tier_test.dart.
  tester.view.physicalSize = const Size(1024, 1366);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (tester.any(find.text('Help'))) return;
  }
  throw StateError('Grid did not render');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _fixtureBoard = _loadFixtureBoard();

  setUp(() {
    // Bypass onboarding for tests that target the board surface directly.
    // The onboarding gate is exercised in test/ui/onboarding/.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding.completed': true,
    });
  });

  testWidgets('App boots and renders the Home Core 48 grid',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(extraOverrides: const []));
    await _settleInitial(tester);

    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Bathroom'), findsOneWidget);
    expect(find.text('All Done'), findsOneWidget);
  });

  testWidgets('Tapping a word button calls TTSEngine.speak with voice_out',
      (WidgetTester tester) async {
    final fakeTts = _RecordingTTSEngine();
    await tester.pumpWidget(
      _wrap(extraOverrides: [
        ttsEngineProvider.overrideWith((ref) => fakeTts),
      ]),
    );
    await _settleInitial(tester);

    await tester.tap(find.text('Want'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fakeTts.calls, hasLength(1));
    expect(fakeTts.calls.single.text, 'want');
  });

  testWidgets('Tapping a phrase button speaks the full phrase',
      (WidgetTester tester) async {
    final fakeTts = _RecordingTTSEngine();
    await tester.pumpWidget(
      _wrap(extraOverrides: [
        ttsEngineProvider.overrideWith((ref) => fakeTts),
      ]),
    );
    await _settleInitial(tester);

    await tester.tap(find.text('Help'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fakeTts.calls, hasLength(1));
    expect(fakeTts.calls.single.text, 'I need help');
  });

  testWidgets('Tapping a folder button does not call TTS',
      (WidgetTester tester) async {
    final fakeTts = _RecordingTTSEngine();
    await tester.pumpWidget(
      _wrap(extraOverrides: [
        ttsEngineProvider.overrideWith((ref) => fakeTts),
      ]),
    );
    await _settleInitial(tester);

    await tester.tap(find.text('Food'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(fakeTts.calls, isEmpty);
  });

  testWidgets(
      'a folder tap does NOT advance Prev: (navigation is not a communication '
      'act) -- guards the context-aware cold-start prior', (tester) async {
    // The context-aware cold-start prior (ADR 0003) relies on this property:
    // because a folder tap returns BEFORE _recordTap (main.dart _handleTap),
    // navigating into a sub-board does not advance the previous-button pointer,
    // so e.g. "eat" -> Food folder -> the food board still ranks under
    // Prev:btn_eat (eat->apple fires on the sub-board). If folder taps ever
    // start recording, that breaks silently; this test fails first.
    final ctx = ContextManager()
      ..recordTap(
        AACButton(
          id: 'btn_eat',
          label: 'Eat',
          labelByLocale: const {},
          type: AACButtonType.word,
          position: (row: 0, col: 0),
          category: 'verbs',
          baseWeight: 0.5,
          iconUri: '',
          voiceOut: 'eat',
        ),
      );
    expect(ctx.previousButtonId, 'btn_eat'); // sanity: a word tap recorded

    await tester.pumpWidget(
      _wrap(extraOverrides: [
        contextManagerProvider.overrideWithValue(ctx),
      ]),
    );
    await _settleInitial(tester);

    await tester.tap(find.text('Food')); // a folder
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      ctx.previousButtonId,
      'btn_eat',
      reason: 'folder navigation must not advance Prev: (returns before '
          '_recordTap); the cold-start prior depends on this',
    );
  });

  testWidgets(
      'tiles are laid out by board position, not by glow/predictions '
      '(motor-planning invariant)', (tester) async {
    // The cold-start prior affects GLOW only; it must never reorder tiles
    // (ADR 0006 motor memory). The grid lays tiles out by their board
    // (row, col); whatever the bandit suggests, positions are fixed. Row 1 of
    // the fixture is I | You | Want | Need (cols 0..3), so their centres must
    // be left-to-right at (about) the same height.
    await tester.pumpWidget(_wrap(extraOverrides: const []));
    await _settleInitial(tester);

    final cx = {
      for (final label in ['I', 'You', 'Want', 'Need'])
        label: tester.getCenter(find.text(label)),
    };
    expect(cx['I']!.dx, lessThan(cx['You']!.dx));
    expect(cx['You']!.dx, lessThan(cx['Want']!.dx));
    expect(cx['Want']!.dx, lessThan(cx['Need']!.dx));
    // Same row: vertical centres line up (tolerant of sub-pixel layout).
    expect((cx['I']!.dy - cx['Need']!.dy).abs(), lessThan(1.0));
  });

  // The reason this whole responsive layer exists: the board must render
  // cleanly on a phone (handoff Rule 3). A RenderFlex/grid overflow throws
  // during pump and fails this test, so it guards against the board "looking
  // bad on iPhone" regressing. Portrait and landscape are both checked.
  for (final sizeCase in const [
    (name: 'iPhone portrait', size: Size(393, 852)),
    (name: 'iPhone landscape', size: Size(852, 393)),
  ]) {
    testWidgets('board renders without overflow on ${sizeCase.name}',
        (tester) async {
      tester.view.physicalSize = sizeCase.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(extraOverrides: const []));
      // Poll for the board (the phone tier reflows + scrolls; no _settleInitial
      // here because that pins a tablet surface). A RenderFlex / grid overflow
      // throws during these pumps and fails the test, which is the point.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        if (tester.any(find.byType(AACGrid))) break;
      }
      // Let the board's scroll metrics settle so the cue resolves (it is driven
      // by ScrollMetricsNotification + a post-frame setState).
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // The board is present and scrolls (phone tier). At the TOP, with rows
      // below, the "more words" cue is shown.
      expect(find.byType(AACGrid), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      expect(find.text('more words'), findsOneWidget);
    });
  }

  testWidgets('the "more words" cue hides once the board is scrolled to bottom',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(extraOverrides: const []));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      if (tester.any(find.byType(AACGrid))) break;
    }
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    // Shown at the top (more rows below).
    expect(find.text('more words'), findsOneWidget);

    // Fling the board to the bottom; the cue must disappear (it is pointless
    // at the end -- the bug this guards).
    final scrollable = find.byType(Scrollable).first;
    await tester.fling(scrollable, const Offset(0, -4000), 6000);
    await tester.pumpAndSettle();
    expect(find.text('more words'), findsNothing);
  });
}
