/// Accessible Switch Scanner Engine.
///
/// Implements clinical scanning for:
/// 1. Single-switch auto-scanning with configurable dwell time (500ms - 2000ms).
/// 2. Dual-switch manual step-and-select scanning.
///
/// Supports hardware switches, keyboard inputs (Space, Enter, Tab, Arrows),
/// gamepads, and large on-screen switch targets.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/settings/settings_repository.dart';
import '../../state/settings_provider.dart';
import '../../state/switch_access_provider.dart';
import '../theme/lighthouse_theme.dart';

class SwitchScanner extends ConsumerStatefulWidget {
  const SwitchScanner({
    required this.board,
    required this.onSelect,
    required this.child,
    super.key,
  });

  final AACBoard board;
  final ValueChanged<AACButton> onSelect;
  final Widget child;

  @override
  ConsumerState<SwitchScanner> createState() => _SwitchScannerState();
}

class _SwitchScannerState extends ConsumerState<SwitchScanner> {
  Timer? _dwellTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startOrUpdateScan();
  }

  @override
  void didUpdateWidget(covariant SwitchScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board.boardId != widget.board.boardId) {
      ref.read(switchFocusIndexProvider.notifier).state = 0;
    }
    _startOrUpdateScan();
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _startOrUpdateScan() {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    final settings = ref.read(settingsNotifierProvider).valueOrNull ??
        SettingsState.defaults;

    if (settings.accessMethod == AccessMethod.switchSingle) {
      final dwell = settings.switchDwellMs.clamp(500, 2000);
      _dwellTimer = Timer.periodic(Duration(milliseconds: dwell), (_) {
        if (!mounted) return;
        _stepForward();
      });
    }
  }


  void _stepForward() {
    if (widget.board.buttons.isEmpty) return;
    final current = ref.read(switchFocusIndexProvider);
    final total = widget.board.buttons.length;
    ref.read(switchFocusIndexProvider.notifier).state = (current + 1) % total;
  }

  void _stepBackward() {
    if (widget.board.buttons.isEmpty) return;
    final current = ref.read(switchFocusIndexProvider);
    final total = widget.board.buttons.length;
    ref.read(switchFocusIndexProvider.notifier).state =
        (current - 1 + total) % total;
  }

  void _activateSelection() {
    if (widget.board.buttons.isEmpty) return;
    final current = ref.read(switchFocusIndexProvider);
    if (current >= 0 && current < widget.board.buttons.length) {
      final btn = widget.board.buttons[current];
      widget.onSelect(btn);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final settings = ref.read(settingsNotifierProvider).valueOrNull ??
        SettingsState.defaults;

    if (settings.accessMethod == AccessMethod.switchSingle) {
      // In single switch mode, any switch key activates selection
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _activateSelection();
      }
    } else if (settings.accessMethod == AccessMethod.switchDual) {
      // In dual switch mode:
      // Switch 1 (Step): Space, Tab, Arrow Right / Down
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.tab ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _stepForward();
      }
      // Switch 2 (Select): Enter, Game Button A, Select
      else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _activateSelection();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _stepBackward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SettingsState>>(settingsNotifierProvider, (_, __) {
      _startOrUpdateScan();
    });

    final settings = ref.watch(settingsNotifierProvider).valueOrNull ??
        SettingsState.defaults;

    if (settings.accessMethod == AccessMethod.switchSingle && _dwellTimer == null) {
      _startOrUpdateScan();
    }

    if (settings.accessMethod == AccessMethod.directTouch) {
      return widget.child;
    }


    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          Expanded(child: widget.child),
          // If dual-switch mode is active, present large high-contrast on-screen switch targets
          if (settings.accessMethod == AccessMethod.switchDual) ...[
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: LhColors.surface,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LhColors.cream2,
                        foregroundColor: LhColors.ink,
                        side: const BorderSide(color: LhColors.line2, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 24),
                      label: Text(
                        Localizations.of<AppLocalizations>(
                                    context, AppLocalizations)
                                ?.switchStep ??
                            'STEP (Space)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _stepForward,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LhColors.amberTint,
                        foregroundColor: LhColors.brown,
                        side: const BorderSide(
                            color: LhColors.amberLine, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_outline,
                          size: 24, color: LhColors.brown),
                      label: Text(
                        Localizations.of<AppLocalizations>(
                                    context, AppLocalizations)
                                ?.switchSelect ??
                            'SELECT (Enter)',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _activateSelection,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
