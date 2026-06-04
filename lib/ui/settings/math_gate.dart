/// Math gate, a low-friction door to gated settings (redesign chrome).
///
/// A one-digit + one-digit addition answered via an on-screen number pad. The
/// pad is deliberate: a TextField depends on the platform soft keyboard, which
/// on a tablet is fragile (it fails to appear inside a dialog when autofocus
/// races the route transition, and iOS suppresses it when the iPad is tethered
/// to a Mac). The keypad has no such dependency and is a better touch target.
///
/// Friction only, NOT security (ADR 0003 § Settings): the threat model is
/// "block accidental child taps", satisfied by any speed bump a child cannot
/// stumble through. Do not "harden" this to a PIN or biometric.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/services.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';
import '../tour/first_use_tip.dart';
import '../tour/tour_controller.dart';

class MathGate extends ConsumerStatefulWidget {
  const MathGate({
    required this.onUnlocked,
    this.questionSeed,
    super.key,
  });

  /// Called once when the parent enters a correct answer.
  final VoidCallback onUnlocked;

  /// Test-only: forces a specific (a, b) sum.
  final ({int a, int b})? questionSeed;

  @override
  ConsumerState<MathGate> createState() => _MathGateState();
}

class _MathGateState extends ConsumerState<MathGate> {
  late final int _a;
  late final int _b;

  /// Digits entered so far. Capped at two (max answer 9 + 9 = 18).
  String _entry = '';
  String? _errorText;

  /// First-use tip (ADR 0020), anchored to the equation.
  final GlobalKey _eqKey = GlobalKey();
  late final FirstUseTipController _tipController;

  @override
  void initState() {
    super.initState();
    final seed = widget.questionSeed;
    if (seed != null) {
      _a = seed.a;
      _b = seed.b;
    } else {
      final now = DateTime.now().microsecondsSinceEpoch;
      _a = 4 + (now % 6);
      _b = 4 + ((now ~/ 7) % 6);
    }
    _tipController = ref.read(firstUseTipControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      _tipController.maybeShow(
        context: context,
        store: ref.read(firstUseTipsStoreProvider),
        tipKey: FirstUseTipsStore.gateKey,
        anchor: _eqKey,
        title: l10n.tipGateTitle,
        body: l10n.tipGateBody,
        gotItLabel: l10n.tipGotIt,
        tourActive: ref.read(tourControllerProvider).active,
        reduceMotion: MediaQuery.maybeOf(context)?.disableAnimations ?? false,
      );
    });
  }

  @override
  void dispose() {
    // Pass our own key so a late gate-dialog teardown cannot remove the NEXT
    // screen's tip (e.g. the editor's), which it has already shown by the time
    // the gate finishes its exit animation.
    _tipController.dismiss(ownerTipKey: FirstUseTipsStore.gateKey);
    super.dispose();
  }

  void _pressDigit(int digit) {
    if (_entry.length >= 2) return;
    setState(() {
      _entry += '$digit';
      _errorText = null;
    });
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() {
      _entry = _entry.substring(0, _entry.length - 1);
      _errorText = null;
    });
  }

  void _submit() {
    final entered = int.tryParse(_entry);
    if (entered == _a + _b) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _errorText = AppLocalizations.of(context).mathGateError;
      _entry = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 26),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.mathGateTitle, style: LhText.dialogTitle),
            const SizedBox(height: 8),
            Text(l10n.mathGateBody, style: LhText.body.copyWith(color: LhColors.ink2)),
            const SizedBox(height: 18),
            Row(
              children: [
                KeyedSubtree(
                  key: _eqKey,
                  child: Text(
                    // Western digits, matching the keypad (not Arabic-Indic).
                    l10n.mathGateEquation('$_a', '$_b'),
                    style: const TextStyle(
                      fontFamily: 'Atkinson Hyperlegible',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: LhColors.ink,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                _AnswerDisplay(entry: _entry),
              ],
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(
                  fontFamily: 'Atkinson Hyperlegible',
                  fontSize: 16,
                  color: Color(0xFFB3261E),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Center(
              child: _Keypad(onDigit: _pressDigit, onBackspace: _backspace),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('mathgate_continue'),
                  onPressed: _entry.isEmpty ? null : _submit,
                  child: Text(l10n.continueLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the digits entered so far; fills and turns amber as you type.
class _AnswerDisplay extends StatelessWidget {
  const _AnswerDisplay({required this.entry});

  final String entry;

  @override
  Widget build(BuildContext context) {
    final filled = entry.isNotEmpty;
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LhColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: filled ? LhColors.amber : LhColors.line2,
          width: 2,
        ),
      ),
      child: Text(
        filled ? entry : '?',
        style: TextStyle(
          fontFamily: 'Atkinson Hyperlegible',
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: filled ? LhColors.ink : LhColors.ink3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// On-screen 1-9 / 0 number pad with a backspace key, kept left-to-right in
/// every locale (like a phone dialpad).
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace});

  final void Function(int) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(int d) => _KeypadKey(
          label: '$d',
          valueKey: ValueKey('mathkey_$d'),
          onTap: () => onDigit(d),
        );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 258),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            key(1), key(2), key(3),
            key(4), key(5), key(6),
            key(7), key(8), key(9),
            const _KeypadKey.spacer(),
            key(0),
            _KeypadKey(
              label: null,
              icon: Icons.backspace_outlined,
              valueKey: const ValueKey('mathkey_backspace'),
              onTap: onBackspace,
            ),
          ],
        ),
      ),
    );
  }
}

class _KeypadKey extends StatefulWidget {
  const _KeypadKey({
    required this.label,
    required this.valueKey,
    required this.onTap,
    this.icon,
  }) : isSpacer = false;

  const _KeypadKey.spacer()
      : label = null,
        icon = null,
        valueKey = null,
        onTap = null,
        isSpacer = true;

  final String? label;
  final IconData? icon;
  final Key? valueKey;
  final VoidCallback? onTap;
  final bool isSpacer;

  @override
  State<_KeypadKey> createState() => _KeypadKeyState();
}

class _KeypadKeyState extends State<_KeypadKey> {
  bool _pressed = false;

  static const double _size = 74;

  @override
  Widget build(BuildContext context) {
    if (widget.isSpacer) return const SizedBox(width: _size, height: _size);
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1.0,
      duration: LhMotion.fast,
      curve: LhMotion.ease,
      child: Material(
        key: widget.valueKey,
        color: LhColors.amberTint,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: SizedBox(
            width: _size,
            height: _size,
            child: widget.icon != null
                ? Icon(widget.icon, size: 28, color: LhColors.ink)
                : Center(
                    child: Text(
                      widget.label!,
                      style: const TextStyle(
                        fontFamily: 'Atkinson Hyperlegible',
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: LhColors.ink,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
