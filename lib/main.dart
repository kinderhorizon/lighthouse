import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/licenses.dart';
import 'config/release_endpoint_guard.dart';
import 'i18n/locale_registry.dart';
import 'l10n/app_localizations.dart';
import 'models/models.dart';
import 'persistence/persistence.dart';
import 'services/services.dart';
import 'state/state.dart';
import 'ui/theme/lighthouse_theme.dart';
import 'ui/ui.dart';

void main() {
  // Compile-time guard: a release build must bake in OTA_BASE_URL,
  // FEEDBACK_URL, and PRIVACY_POLICY_URL or it fails to compile. No runtime
  // effect; see release_endpoint_guard.dart.
  const _ = releaseEndpointGuard;

  final crashStore = CrashLogStore();
  final crashCapture = CrashCapture(
    store: crashStore,
    deviceInfoSource: DeviceInfoSource(),
  );

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      crashCapture.install();

      // Surface the bundled font + TTS-provider licences on the in-app
      // "Open-source licences" page alongside the auto-collected package
      // licences (lib/config/licenses.dart). Lazy: read only when opened.
      registerBundledLicenses();

      // If the DB is corrupt (e.g. mdbx damage after a force-kill), openForApp
      // discards it and starts fresh rather than letting the app brick on the
      // splash forever; note the original failure in the crash log. Only glow
      // learning is lost (see IsarSetup.openForApp).
      final isar = await IsarSetup.openForApp(
        onCorruptDbReset: crashCapture.zoneErrorHandler,
      );

      // Wire the bandit-state diagnostic counters into crash logs (ADR
      // 0002). Updated lazily; the values surface in any crash captured
      // after at least one query.
      final repo = BanditRepository(isar);
      _refreshBanditDiagnostics(crashCapture, repo);

      runApp(
        // RestartWidget wraps the scope so an OTA apply can re-mount the whole
        // app (re-reading corrected content from disk) without an OS process
        // restart, which iOS forbids. See ui/widgets/restart_widget.dart.
        RestartWidget(
          child: ProviderScope(
            overrides: [
              crashLogStoreProvider.overrideWithValue(crashStore),
              crashCaptureProvider.overrideWithValue(crashCapture),
              isarProvider.overrideWithValue(isar),
            ],
            child: const LighthouseApp(),
          ),
        ),
      );
    },
    crashCapture.zoneErrorHandler,
  );
}

Future<void> _refreshBanditDiagnostics(
  CrashCapture capture,
  BanditRepository repo,
) async {
  try {
    capture.isarDbSizeBytes = await repo.approximateSizeBytes();
    capture.uniqueContextKeysCount = await repo.uniqueContextKeyCount();
  } catch (_) {
    // Diagnostics are best-effort; never block startup on them.
  }
}

class LighthouseApp extends ConsumerWidget {
  const LighthouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final localeCode = settingsAsync.valueOrNull?.localeOverride;
    // Resolve the primary UI face: Atkinson Hyperlegible app-wide (the redesign
    // face), but a locale that requires its own font (Arabic -> Cairo) wins when
    // chosen explicitly. Cairo is always a fontFamilyFallback in the theme so
    // Arabic glyphs render from the bundled face even under "follow system" or
    // when text mixes scripts.
    final fontFamily = (localeCode == null
            ? null
            : LocaleRegistry.specForCode(localeCode)?.requiredFontFamily) ??
        'Atkinson Hyperlegible';
    return MaterialApp(
      title: 'Lighthouse AAC',
      theme: buildLighthouseTheme(fontFamily: fontFamily),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Both derive from the locale registry (ADR 0008); adding a language is
      // a registry edit, not a change here.
      supportedLocales: LocaleRegistry.supportedLocales,
      localeResolutionCallback: LocaleRegistry.resolve,
      locale: localeCode == null ? null : Locale(localeCode),
      home: const LighthouseAppRoot(),
    );
  }
}

/// Top-level routing: while the onboarding repo loads, show a splash; if
/// not yet completed, run the onboarding flow; otherwise show the board.
class LighthouseAppRoot extends ConsumerWidget {
  const LighthouseAppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingNotifierProvider);

    return onboardingAsync.when(
      data: (state) {
        ref.read(crashCaptureProvider).lastUiRoute =
            state.completed ? '/board' : '/onboarding';
        return state.completed
            ? const _BoardScreen()
            : const OnboardingFlow();
      },
      loading: () => const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Scaffold(
        body: SafeArea(child: _BoardLoadError(error: e)),
      ),
    );
  }
}

/// True on a phone-tier device held in landscape, where vertical space is
/// scarce and the chrome compresses (handoff Rule 3).
bool _isLandscapePhone(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide < 600 && size.width > size.height;
}

class _BoardScreen extends ConsumerWidget {
  const _BoardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(defaultBoardProvider);
    final board = ref.watch(activeBoardProvider);
    final depth = ref.watch(boardStackProvider).length;

    ref.read(crashCaptureProvider).lastUiRoute =
        board == null ? '/loading' : '/grid/${board.boardId}';

    Widget body;
    if (boardAsync.hasError) {
      body = _BoardLoadError(error: boardAsync.error!);
    } else if (board == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _BoardView(board: board);
    }

    // End-of-first-run handoff: the onboarding "Take the quick tour" button set
    // this flag, then completed onboarding (which mounts this board). Start the
    // tour once, after the first frame, and clear the flag.
    if (ref.watch(tourPendingStartProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.read(tourPendingStartProvider)) return;
        ref.read(tourPendingStartProvider.notifier).state = false;
        ref.read(tourControllerProvider.notifier).start();
      });
    }

    final boardScaffold = PopScope(
      canPop: depth <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(boardStackProvider.notifier).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // Compress the bar on a landscape phone, where vertical space is
          // scarce (handoff Rule 3: app bar ~54 vs the default). Other devices
          // keep the standard height.
          toolbarHeight: _isLandscapePhone(context) ? 54 : null,
          leading: depth > 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      ref.read(boardStackProvider.notifier).pop(),
                )
              : null,
          title: Text(
            board?.boardNameFor(Localizations.localeOf(context).languageCode) ??
                'Lighthouse AAC',
          ),
          actions: [
            IconButton(
              key: tourArrangeKey,
              tooltip: AppLocalizations.of(context).editBoardTooltip,
              icon: const Icon(Icons.dashboard_customize_outlined),
              onPressed: () => showBoardEditorGate(
                context,
                rootBoardId: board?.boardId ?? 'core_main',
              ),
            ),
            IconButton(
              key: tourSettingsKey,
              tooltip: AppLocalizations.of(context).settingsTooltip,
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsPrimaryScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
    // The tour overlay sits ABOVE the Scaffold (so its dim covers the app bar
    // too). It renders nothing while the tour is inactive.
    return Stack(
      fit: StackFit.expand,
      children: [boardScaffold, const TourOverlay()],
    );
  }
}

class _BoardView extends ConsumerWidget {
  const _BoardView({required this.board});

  final AACBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glow = ref.watch(currentGlowProvider).valueOrNull ?? const {};
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final glowStyle = settings?.glowStyle ?? SettingsState.defaults.glowStyle;
    final hitboxMagnitude =
        settings?.hitboxMagnitude ?? SettingsState.defaults.hitboxMagnitude;
    final hideTileText =
        settings?.hideTileText ?? SettingsState.defaults.hideTileText;
    final hidePictogram =
        settings?.hidePictogram ?? SettingsState.defaults.hidePictogram;
    // Hydrate the custom-voice map (ADR 0019) eagerly so a tap can prefer a
    // parent-recorded clip over TTS without awaiting a load on the hot path.
    ref.watch(customVoiceProvider);
    // The favourites strip is a home-only surface (ADR 0013); it self-hides
    // when there are no pins, so on a sub-board (or a fresh device) it adds
    // nothing.
    final isHome = board.boardId == 'core_main';
    // Color favourites by their OWN category, which may come from any board
    // (a pinned Activities / Body / Time word uses a category the home board's
    // color_key does not define). Merge every board's color_key so those resolve
    // correctly instead of falling back to grey (QA B1). Fitzgerald colors are
    // consistent across boards, so key collisions are benign. editableBoards is
    // already loaded to resolve the pins themselves; fall back to the home key
    // until it arrives.
    final allBoards = ref.watch(editableBoardsProvider).valueOrNull;
    final favColorKey = (allBoards == null || allBoards.isEmpty)
        ? board.colorKey
        : <String, String>{for (final b in allBoards) ...b.colorKey};

    // Handoff Rule 3 (phone / small screens): pick a column count by the
    // device's shortest side and LOCK it across rotation, then keep tiles at a
    // legible fixed size and SCROLL rather than shrinking below the floor.
    // Large tablets keep the native board and fill the screen (unchanged).
    final sizing = boardSizingFor(
      shortestSide: MediaQuery.sizeOf(context).shortestSide,
      nativeColumns: board.gridDimensions.cols,
    );
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // tourSentenceKey / tourBoardKey mark the guided-tour spotlight targets
        // (ADR 0020). KeyedSubtree keeps the existing widgets untouched.
        KeyedSubtree(
          key: tourSentenceKey,
          child: SentenceBar(
            compact: sizing.tier == BoardSizeTier.phone,
            hideText: hideTileText,
            hideIcon: hidePictogram,
          ),
        ),
        if (isHome)
          FavouritesStrip(
            onTap: (button) => _handleTap(context, ref, button),
            colorKey: favColorKey,
            hideText: hideTileText,
            hideIcon: hidePictogram,
          ),
        Expanded(
          child: KeyedSubtree(
            key: tourBoardKey,
            child: () {
            final grid = AACGrid(
              board: board,
              glow: glow,
              glowStyle: glowStyle,
              hitboxMagnitude: hitboxMagnitude,
              hideTileText: hideTileText,
              hidePictogram: hidePictogram,
              columns: sizing.columns,
              scroll: sizing.scrolls,
              // Home fills the screen; a sub-board keeps its tiles large and
              // top-aligned with calm space below (handoff sub-board rule). In
              // scroll mode (phone / small tablet) the board reflows +
              // scrolls, so top-align does not apply.
              topAlign: !isHome && !sizing.scrolls,
              onButtonTap: (button) => _handleTap(context, ref, button),
              onButtonLongPress: (button) =>
                  _handleLongPress(context, ref, button),
            );
            // On a scrolling board, show a "more words" cue ONLY while there
            // are rows below the current scroll position; it hides at the
            // bottom (and never shows if the board fits). A tablet's filled
            // board never scrolls, so no cue.
            return sizing.scrolls
                ? _ScrollHintedBoard(cueText: l10n.boardScrollHint, child: grid)
                : grid;
          }(),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref,
    AACButton button,
  ) async {
    if (button.type == AACButtonType.folder) {
      await _handleFolderTap(context, ref, button);
      return;
    }

    final settings = ref.read(settingsNotifierProvider).valueOrNull ??
        SettingsState.defaults;
    final mode = settings.ttsMode;

    // Record the tap for the bandit + event log EXCEPT in On-request mode, where
    // the silent tap is not the communication act (the long-press is, and
    // _handleLongPress is the record path there). Recording here would let an
    // exploratory/accidental tap train the bandit + the favourites-frequency log
    // (ADR 0013) AND double-count the subsequent long-press (review M1).
    // Fire-and-forget: persistence must NEVER block the child hearing the word
    // (communication latency first, bookkeeping second). _recordTap composes the
    // state-key from the CURRENT in-memory context BEFORE it advances, so the
    // bandit still observes the pre-tap state even though the call is async.
    if (mode != TtsMode.onRequest) {
      unawaited(_recordTap(ref, button));
    }

    final locale = Localizations.localeOf(context);
    final label = button.labelFor(locale.languageCode);
    final voice = button.voiceOutFor(locale.languageCode) ?? '';

    switch (mode) {
      case TtsMode.on:
        if (voice.isNotEmpty) {
          await _speakSafely(ref, button, voice, locale);
        }
        // The word lands in the sentence bar (ADR 0010); the composed sentence
        // is replayed later from the bar's speak control. A PHRASE button is a
        // complete utterance on its own, so commit() leaves the bar untouched.
        ref.read(utteranceProvider.notifier).commit(button);
      case TtsMode.off:
        // A silent selection still counts as a communication act and still
        // builds the sentence.
        ref.read(utteranceProvider.notifier).commit(button);
      case TtsMode.onRequest:
        // Tap is silent; the long-press is the communication act. Do not
        // auto-return on a silent tap (it would navigate away before the
        // child long-presses).
        return;
      case TtsMode.als:
        // Keep ALS consistent with on/off: the word also builds the sentence
        // bar (review NEW-E), so the speaker control works in ALS too.
        ref.read(utteranceProvider.notifier).commit(button);
        if (!context.mounted) return;
        // For a PHRASE button the tile label is the short word ("Bathroom") but
        // the utterance is the full phrase ("I need to go to the bathroom"),
        // which is what the parent should voice in ALS (QA C2). Words show their
        // label.
        final alsText =
            button.type == AACButtonType.phrase && voice.isNotEmpty
                ? voice
                : label;
        await ALSWordScreen.show(context, text: alsText);
    }

    if (!context.mounted) return;
    _maybeReturnHome(context, ref, settings);
  }

  /// After a communication act inside a sub-board, return to the home board so
  /// the next core word is one tap away and the child is never stranded in a
  /// folder (ADR 0009). No-op at the root or when the clinician disables it.
  void _maybeReturnHome(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
  ) {
    if (!settings.autoReturnToHome || !context.mounted) return;
    ref.read(boardStackProvider.notifier).resetToRoot();
  }

  Future<void> _handleLongPress(
    BuildContext context,
    WidgetRef ref,
    AACButton button,
  ) async {
    if (button.type == AACButtonType.folder) return;

    final settings = ref.read(settingsNotifierProvider).valueOrNull ??
        SettingsState.defaults;
    if (settings.ttsMode != TtsMode.onRequest) return;

    // A long-press in On-request mode IS the child's tap, just
    // surfaced through a different gesture. Same bandit + log update.
    unawaited(_recordTap(ref, button));

    final locale = Localizations.localeOf(context);
    final voice = button.voiceOutFor(locale.languageCode) ?? '';
    if (voice.isEmpty) return;
    await _speakSafely(ref, button, voice, locale);

    // The long-press is the communication act in On-request mode, so it is
    // also what commits to the sentence bar (ADR 0010): a word accumulates, a
    // phrase speaks standalone and leaves the bar untouched.
    ref.read(utteranceProvider.notifier).commit(button);

    if (!context.mounted) return;
    _maybeReturnHome(context, ref, settings);
  }

  /// Speaks [button]'s voice and swallows any engine/player failure. Speech must
  /// never crash a tap (review NEW-F): the child still gets the visual
  /// selection, and a transient audio-player error is not worth propagating to
  /// the crash logger or aborting the rest of the tap handler.
  ///
  /// ADR 0019: if the parent recorded a custom voice for this tile, that
  /// recording plays INSTEAD of the built-in voice. The in-flight TTS clip (if
  /// any) is stopped first so the two players never overlap. The custom-voice
  /// map is hydrated eagerly in [_BoardView], so this read is non-blocking; on
  /// the rare pre-hydration tap it returns null and the built-in voice plays.
  Future<void> _speakSafely(
      WidgetRef ref, AACButton button, String voice, Locale locale) async {
    try {
      final customPath =
          ref.read(customVoiceProvider.notifier).pathFor(button.id);
      if (customPath != null) {
        await ref.read(ttsEngineProvider).stop();
        // If the mapped recording is missing/corrupt, play() returns false; fall
        // through to TTS so the tile is never silent (ADR 0004 / ADR 0019).
        final played = await ref.read(customVoicePlayerProvider).play(customPath);
        if (played) return;
      }
      await ref.read(ttsEngineProvider).speak(voice, locale: locale);
    } catch (_) {
      // Intentionally ignored; see doc comment.
    }
  }

  /// Records a tap (bandit observation + raw event log + context advance).
  /// Folder navigation is NOT a communication act and does not call through.
  ///
  /// Two things happen here, both deliberate (review NEW-A):
  /// 1. The prediction set the child was shown is snapshotted SYNCHRONOUSLY,
  ///    before any await, so a queued tap penalises the glow that was actually
  ///    on screen at tap time.
  /// 2. The persistence is serialized through the shared [tapQueueProvider] so
  ///    overlapping fire-and-forget taps cannot interleave the bandit
  ///    read-modify-write (which silently lost rewards: "more more" counted
  ///    once) or compose a state-key against a half-advanced context. Each tap
  ///    sees the context the previous tap left behind, the correct sequential
  ///    semantics. Sentence-bar edits (backspace / clear) enqueue on the SAME
  ///    queue, so a delete's context revert always lands after any in-flight
  ///    tap record rather than being overwritten by it.
  Future<void> _recordTap(WidgetRef ref, AACButton button) {
    final predictions = ref
            .read(currentPredictionsProvider)
            .valueOrNull
            ?.map((p) => p.button)
            .toList() ??
        const <AACButton>[];
    return ref
        .read(tapQueueProvider)
        .add(() => _persistTap(ref, button, predictions));
  }

  Future<void> _persistTap(
    WidgetRef ref,
    AACButton button,
    List<AACButton> predictions,
  ) async {
    try {
      final ctx = ref.read(contextManagerProvider);
      final wifiHash =
          await ref.read(wifiSourceProvider).hashOfCurrentSsid();
      final stateKey = ctx.currentStateKey(
        now: DateTime.now(),
        locale: _activeLocaleFromSettings(ref),
        wifiHash: wifiHash,
      );

      await ref.read(banditUpdaterProvider).applyTap(
            stateKey: stateKey,
            tappedButton: button,
            top3Predictions: predictions,
          );

      await ref.read(banditRepositoryProvider).appendEvent(
            RawEventLogV1()
              ..timestamp = DateTime.now().toUtc()
              ..eventType = 'tap'
              ..buttonId = button.id
              ..boardId = board.boardId
              ..stateKey = stateKey,
          );

      // After we've recorded the observation, evolve the in-memory
      // context for the NEXT tap.
      ctx.recordTap(button);

      // Invalidate the prediction cache so the next frame sees a
      // fresh top-K under the evolved context.
      ref.read(contextEpochProvider.notifier).bump();
    } catch (_) {
      // Persistence failures must never silently kill a child's
      // ability to communicate. We swallow here; the crash logger
      // (ADR 0002) will have captured anything that propagated, and
      // the diagnostic counters (db size, unique-context-key count)
      // surface aggregate health in any future crash dump.
    }
  }

  /// The effective locale the bandit indexes its DayType on. The settings
  /// override wins when set; otherwise we resolve the device locale against the
  /// supported set (the same rule MaterialApp applies), so a follow-system
  /// Arabic/Spanish user is not silently modeled as English. Resolved from
  /// settings rather than BuildContext because _recordTap can run after the
  /// widget is unmounted.
  Locale _activeLocaleFromSettings(WidgetRef ref) {
    final override =
        ref.read(settingsNotifierProvider).valueOrNull?.localeOverride;
    return LocaleRegistry.effectiveLocale(override);
  }

  Future<void> _handleFolderTap(
    BuildContext context,
    WidgetRef ref,
    AACButton folder,
  ) async {
    final linkId = folder.linkId;
    if (linkId == null) return;

    final registry = await ref.read(boardRegistryProvider.future);
    final loaded = await registry.tryLoad(linkId);
    if (!context.mounted) return;

    if (loaded == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(AppLocalizations.of(context).packNotLoaded(folder.label)),
        ),
      );
      return;
    }

    ref.read(boardStackProvider.notifier).push(loaded);
  }
}

/// Wraps a scrolling board and shows a "more words" cue ONLY while there are
/// rows below the current scroll position. The cue hides once the board is
/// scrolled to the bottom (where it would be pointless) and never appears if
/// the content already fits. Listens to the board's own scroll metrics, so it
/// needs no external controller.
class _ScrollHintedBoard extends StatefulWidget {
  const _ScrollHintedBoard({required this.cueText, required this.child});

  final String cueText;
  final Widget child;

  @override
  State<_ScrollHintedBoard> createState() => _ScrollHintedBoardState();
}

class _ScrollHintedBoardState extends State<_ScrollHintedBoard> {
  bool _showCue = false;

  // More below = the board overflows AND we are not yet at the bottom (small
  // tolerance so the last pixel does not flicker the cue).
  void _apply(ScrollMetrics m) {
    final hasMore = m.hasContentDimensions &&
        m.maxScrollExtent > 0 &&
        m.pixels < m.maxScrollExtent - 8;
    if (hasMore == _showCue) return;
    // Deferred: ScrollMetricsNotification can dispatch during layout, where a
    // synchronous setState is illegal. A user scroll (ScrollNotification) is
    // outside layout, but routing both through one post-frame update keeps it
    // simple and always safe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showCue != hasMore) {
        setState(() => _showCue = hasMore);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          // ScrollMetricsNotification covers the initial layout + content-size
          // changes (so the cue shows at the top when the board overflows);
          // ScrollNotification covers user scrolling (so it hides at the
          // bottom). Neither subclasses the other, so listen for both.
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              _apply(n.metrics);
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                _apply(n.metrics);
                return false;
              },
              child: widget.child,
            ),
          ),
        ),
        if (_showCue) _ScrollCue(text: widget.cueText),
      ],
    );
  }
}

/// A quiet "more words" cue under a scrolling board (phone / small screens), so
/// a parent knows lower rows are reached by scrolling. Decorative: hidden from
/// the semantics tree (the board itself is the accessible surface).
class _ScrollCue extends StatelessWidget {
  const _ScrollCue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 5, 0, 9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: LhColors.ink3),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LhColors.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardLoadError extends StatelessWidget {
  const _BoardLoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).couldNotLoadBoard,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
