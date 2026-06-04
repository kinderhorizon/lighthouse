/// Sentence bar (utterance strip) - ADR 0010, redesign chrome.
///
/// Sits above the board grid: a warm surface card with the running sentence as
/// a horizontal row of token chips (pictogram + word), and three 64px controls,
/// backspace, clear, and Speak. Speak is tonal (amber-tint) when there is
/// nothing to say and solid brown when there is. Tapping the chip area also
/// speaks the sentence, a large forgiving target.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../logic/logic.dart';
import '../models/models.dart';
import '../state/state.dart';
import 'theme/lighthouse_theme.dart';

class SentenceBar extends ConsumerWidget {
  const SentenceBar({
    this.compact = false,
    this.hideText = false,
    this.hideIcon = false,
    super.key,
  });

  /// Narrow-width (phone) layout: chips drop their text label and show the
  /// pictogram only (the word is still spoken), so several words fit instead of
  /// ~1.5; controls shrink to 50px. On a tablet, keep the full text chips and
  /// 64px controls. Handoff Rule 3 (compact sentence bar).
  final bool compact;

  /// Mirror the grid's tile-content settings on the sentence-bar chips, so the
  /// running sentence matches the board (word-only or picture-only). Both can
  /// never be on at once; a chip never collapses to empty (guard in _TokenChip).
  final bool hideText;
  final bool hideIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(utteranceProvider);
    final l10n = AppLocalizations.of(context);
    final hasTokens = tokens.isNotEmpty;
    final chipsHeight = compact ? 56.0 : 72.0;

    return Semantics(
      container: true,
      label: l10n.sentenceBarLabel,
      child: Padding(
        padding: compact
            ? const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 2)
            : const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 74 : 96),
          decoration: BoxDecoration(
            color: LhColors.surface,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(color: LhColors.line, width: 1.5),
            boxShadow: LhShadows.card,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  onTap: hasTokens ? () => _speak(context, ref) : null,
                  child: SizedBox(
                    height: chipsHeight,
                    child: hasTokens
                        ? _ChipStrip(
                            tokens: tokens,
                            compact: compact,
                            hideText: hideText,
                            hideIcon: hideIcon,
                          )
                        : _Placeholder(text: l10n.sentenceBarHint),
                  ),
                ),
              ),
              SizedBox(width: compact ? 2 : 4),
              _Control(
                icon: Icons.backspace_outlined,
                tooltip: l10n.sentenceBackspace,
                compact: compact,
                onPressed: hasTokens
                    ? () => _editSentence(
                          ref,
                          () => ref.read(utteranceProvider.notifier).backspace(),
                        )
                    : null,
              ),
              _Control(
                icon: Icons.close_rounded,
                tooltip: l10n.sentenceClear,
                compact: compact,
                onPressed: hasTokens
                    ? () => _editSentence(
                          ref,
                          () => ref.read(utteranceProvider.notifier).clear(),
                        )
                    : null,
              ),
              _SpeakButton(
                enabled: hasTokens,
                tooltip: l10n.sentenceSpeak,
                compact: compact,
                onPressed: () => _speak(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Runs a sentence-bar edit (backspace / clear), then re-derives the bandit
  /// context from what is LEFT on the bar and bumps the context epoch so the
  /// glow re-predicts. Without this, edits only mutate the visible bar while the
  /// predictions stay keyed on the already-deleted word (a normal tap advances
  /// the context via _recordTap + epoch bump in main.dart; a delete must move it
  /// back the same way). The semantic-boost overlay already follows the bar via
  /// `utterance.last`; this keeps the underlying bandit ranking in sync too.
  ///
  /// The revert is enqueued on the SHARED [tapQueueProvider], the same FIFO the
  /// fire-and-forget tap records use. A tap's context advance runs only after
  /// its bandit write settles, so if a tap is still draining when the parent
  /// deletes, a synchronous revert here would be OVERWRITTEN by that late tap
  /// (re-pointing the glow at the just-deleted word). Funnelling both through
  /// one queue makes the delete win, since it was enqueued last. The bar state
  /// is captured NOW so a rapid second edit cannot change what this revert
  /// syncs to.
  void _editSentence(WidgetRef ref, void Function() mutate) {
    mutate();
    final sentence = ref.read(utteranceProvider);
    ref.read(tapQueueProvider).add(() async {
      ref.read(contextManagerProvider).syncToSentence(sentence);
      ref.read(contextEpochProvider.notifier).bump();
    });
  }

  Future<void> _speak(BuildContext context, WidgetRef ref) async {
    final tokens = ref.read(utteranceProvider);
    if (tokens.isEmpty) return;
    final locale = Localizations.localeOf(context);
    final engine = ref.read(ttsEngineProvider);
    final voices = ref.read(customVoiceProvider.notifier);
    // Folders never reach the bar, but filter defensively to match the composer.
    final speakable =
        tokens.where((t) => t.type != AACButtonType.folder).toList();
    // Does any tile in this sentence carry a parent-recorded clip? If not, keep
    // the whole replay on the gapless bundled path (best quality, ADR 0010).
    final hasCustomVoice = speakable.any((t) => voices.pathFor(t.id) != null);
    try {
      // Cancel any in-flight per-word playback before replaying the sentence.
      // Tapping a word speaks it immediately on the shared audio player; without
      // this stop, that fire-and-forget clip can race the replay and swallow the
      // first word (clinical review: "I want water didn't repeat").
      await engine.stop();
      if (!hasCustomVoice) {
        // Pass the ordered word list (not a single string) so the engine can
        // concatenate the per-word bundled clips and keep the replay on the
        // reliable path (ADR 0010).
        final words = composeUtteranceTokens(tokens, locale.languageCode);
        if (words.isNotEmpty) await engine.speakSequence(words, locale: locale);
      } else {
        // Mixed sentence: a self-made tile with a recorded clip must be HEARD in
        // the replay, not silently swapped for TTS (clinical review). Speak each run
        // of ordinary tiles gaplessly via speakSequence, breaking only to play a
        // recorded clip in order. This keeps clinical review's gapless feel within
        // runs while honouring the recording at each custom tile.
        final player = ref.read(customVoicePlayerProvider);
        var run = <AACButton>[];
        Future<void> flushRun() async {
          if (run.isEmpty) return;
          final words = composeUtteranceTokens(run, locale.languageCode);
          run = <AACButton>[];
          if (words.isNotEmpty) await engine.speakSequence(words, locale: locale);
        }

        for (final token in speakable) {
          final clip = voices.pathFor(token.id);
          if (clip != null) {
            await flushRun();
            await engine.stop();
            // A missing/corrupt recording returns false: don't drop the word,
            // fold it back into the TTS run so it is still spoken in order via
            // speakSequence (ADR 0019: a tile is never silent).
            final played = await player.playToCompletion(clip);
            if (!played) run.add(token);
          } else {
            run.add(token);
          }
        }
        await flushRun();
      }
    } finally {
      // Auto-clear after the sentence plays (clinical review, 2026-05-29): the bar resets
      // for the next message. In a `finally` so a playback error still clears
      // the bar rather than stranding stale tokens (clinical review: "does not always
      // auto clear"). Resync so the post-speak glow reflects a fresh start, not
      // the just-spoken last word.
      _editSentence(ref, () => ref.read(utteranceProvider.notifier).clear());
    }
  }
}

class _ChipStrip extends StatelessWidget {
  const _ChipStrip({
    required this.tokens,
    this.compact = false,
    this.hideText = false,
    this.hideIcon = false,
  });

  final List<AACButton> tokens;
  final bool compact;
  final bool hideText;
  final bool hideIcon;

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4, horizontal: 2),
      itemCount: tokens.length,
      separatorBuilder: (_, __) => SizedBox(width: compact ? 6 : 8),
      itemBuilder: (context, i) => _TokenChip(
        token: tokens[i],
        label: tokens[i].labelFor(languageCode),
        compact: compact,
        hideText: hideText,
        hideIcon: hideIcon,
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({
    required this.token,
    required this.label,
    this.compact = false,
    this.hideText = false,
    this.hideIcon = false,
  });

  final AACButton token;
  final String label;

  /// Phone layout: pictogram-only chip (the word is still spoken on tap),
  /// so several fit. Falls back to text when the token has no pictogram.
  final bool compact;

  /// The board's tile-content settings, mirrored onto the chip.
  final bool hideText;
  final bool hideIcon;

  @override
  Widget build(BuildContext context) {
    // Show the pictogram unless it is turned off (setting) or absent.
    final showIcon = !hideIcon && token.iconUri.isNotEmpty;
    // Show the word when the word setting allows it and we are not in the phone
    // compact layout (which drops labels to fit more words); always show it when
    // there is no pictogram, so a chip is never empty.
    final showText = (!hideText && !compact) || !showIcon;
    return Container(
      height: compact ? 56 : 64,
      padding: compact
          ? const EdgeInsets.all(6)
          : const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: LhColors.line, width: 1.5),
        boxShadow: [
          BoxShadow(color: LhColors.inkAlpha(.05), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            _ChipIcon(uri: token.iconUri, size: compact ? 44 : 48),
            if (showText) const SizedBox(width: 8),
          ],
          if (showText)
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Atkinson Hyperlegible',
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: LhColors.ink,
              ),
            ),
        ],
      ),
    );
  }
}

/// Token thumbnail. Bundled pictograms are asset paths; parent-authored custom
/// buttons (ADR 0012) carry an absolute file path, so each renders from the
/// right source. A missing image collapses to nothing rather than a
/// broken-image glyph.
class _ChipIcon extends StatelessWidget {
  const _ChipIcon({required this.uri, this.size = 48});

  final String uri;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget onError(BuildContext _, Object __, StackTrace? ___) =>
        const SizedBox.shrink();
    final image = uri.startsWith('assets/')
        ? Image.asset(uri, width: size, height: size, fit: BoxFit.contain, errorBuilder: onError)
        : Image.file(File(uri), width: size, height: size, fit: BoxFit.contain, errorBuilder: onError);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: LhColors.cream,
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      child: image,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Atkinson Hyperlegible',
            fontSize: 20,
            color: LhColors.ink3,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 50.0 : 64.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          hoverColor: LhColors.cream2,
          child: SizedBox(
            width: side,
            height: side,
            child: Icon(
              icon,
              size: compact ? 26 : 30,
              color: onPressed == null ? LhColors.ink3 : LhColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeakButton extends StatelessWidget {
  const _SpeakButton({
    required this.enabled,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  });

  final bool enabled;
  final String tooltip;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 50.0 : 64.0;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: enabled ? LhColors.brown : LhColors.amberTint,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          elevation: enabled ? 1 : 0,
          shadowColor: LhColors.inkAlpha(.2),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: side,
              height: side,
              child: Icon(
                Icons.volume_up_rounded,
                size: compact ? 26 : 30,
                color: enabled ? Colors.white : LhColors.amberDeep,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
