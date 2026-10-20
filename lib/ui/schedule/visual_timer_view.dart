/// AAC-friendly Visual Countdown Timer (Time Timer style).
/// Displays time passage as a diminishing colored sector, accessible for
/// autistic individuals and users who struggle with abstract digital clocks.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/locale_registry.dart';
import '../../models/daily_schedule.dart';
import '../../state/state.dart';
import '../theme/lighthouse_theme.dart';

class VisualTimerView extends ConsumerStatefulWidget {
  const VisualTimerView({
    super.key,
    this.initialMinutes = 5,
    this.associatedActivity,
  });

  final int initialMinutes;
  final ScheduleActivity? associatedActivity;

  @override
  ConsumerState<VisualTimerView> createState() => _VisualTimerViewState();
}

class _VisualTimerViewState extends ConsumerState<VisualTimerView>
    with SingleTickerProviderStateMixin {
  late int _totalSeconds;
  late int _remainingSeconds;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final mins = widget.associatedActivity?.durationMinutes ?? widget.initialMinutes;
    _totalSeconds = (mins > 0 ? mins : 5) * 60;
    _remainingSeconds = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setDuration(int minutes) {
    _timer?.cancel();
    setState(() {
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
    });
  }

  void _togglePlayPause() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_remainingSeconds <= 0) {
      _remainingSeconds = _totalSeconds;
    }
    _timer?.cancel();
    setState(() => _isRunning = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _onFinished();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _isRunning = false;
    });
  }

  Future<void> _onFinished() async {
    final tts = ref.read(ttsEngineProvider);
    final locale = Localizations.localeOf(context);
    final lang = LocaleRegistry.codeForLocale(locale);

    final isAr = lang.startsWith('ar');
    final isDe = lang.startsWith('de');
    final isDz = lang == 'ar_dz' || lang == 'ar-DZ';

    final text = isDz
        ? 'انتهى الوقت! كملنا!'
        : (isAr
            ? 'انتهى الوقت! حان وقت النشاط التالي.'
            : (isDe
                ? 'Die Zeit ist abgelaufen! Fertig!'
                : 'Time is up! All done!'));

    await tts.speak(text, locale: locale);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: LhColors.amberDeep,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isRtl = LocaleRegistry.isRtl(locale);
    final fraction = _totalSeconds > 0 ? (_remainingSeconds / _totalSeconds) : 0.0;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            if (widget.associatedActivity != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ScheduleActivityCategory.colorFor(
                    widget.associatedActivity!.category,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LhColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 20, color: LhColors.ink),
                    const SizedBox(width: 8),
                    Text(
                      widget.associatedActivity!.labelFor(
                        LocaleRegistry.codeForLocale(locale),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: LhColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Visual Circular Disc Timer
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(250, 250),
                      painter: _TimeTimerPainter(
                        fractionRemaining: fraction,
                        isFinished: _remainingSeconds == 0,
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(_remainingSeconds),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: LhColors.ink,
                          ),
                        ),
                        Text(
                          _remainingSeconds == 0
                              ? 'Finished!'
                              : (_isRunning ? 'Counting down' : 'Paused'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _remainingSeconds == 0
                                ? Colors.red
                                : (_isRunning ? LhColors.green : LhColors.ink3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Controls: Start/Pause, Reset
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 26),
                  label: Text(_isRunning ? 'Pause' : 'Start',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isRunning ? LhColors.amberDeep : LhColors.brown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _togglePlayPause,
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 24),
                  label: const Text('Reset', style: TextStyle(fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LhColors.ink,
                    side: const BorderSide(color: LhColors.line2, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _resetTimer,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Quick Preset Minute Buttons
            const Text(
              'Quick Presets:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: LhColors.ink2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [1, 2, 5, 10, 15, 30].map((mins) {
                final isSelected = _totalSeconds == mins * 60;
                return ChoiceChip(
                  label: Text('$mins min'),
                  selected: isSelected,
                  selectedColor: LhColors.brown,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : LhColors.ink,
                  ),
                  onSelected: (_) => _setDuration(mins),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the diminishing colored visual timer disc.
class _TimeTimerPainter extends CustomPainter {
  const _TimeTimerPainter({
    required this.fractionRemaining,
    required this.isFinished,
  });

  final double fractionRemaining;
  final bool isFinished;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Clock face background
    final facePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 4, facePaint);

    // 2. Dial border
    final borderPaint = Paint()
      ..color = LhColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 4, borderPaint);

    // 3. Tick marks for every 5 minutes (12 ticks)
    final tickPaint = Paint()
      ..color = LhColors.ink3
      ..strokeWidth = 2;
    for (int i = 0; i < 12; i++) {
      final angle = i * (math.pi / 6) - (math.pi / 2);
      final p1 = Offset(
        center.dx + (radius - 12) * math.cos(angle),
        center.dy + (radius - 12) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 4) * math.cos(angle),
        center.dy + (radius - 4) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 4. Diminishing colored disc/wedge (starts at 12 o'clock / -pi/2, sweeps clockwise)
    if (fractionRemaining > 0) {
      final sweepAngle = 2 * math.pi * fractionRemaining;
      final wedgePaint = Paint()
        ..color = fractionRemaining > 0.3
            ? const Color(0xFFE53935).withValues(alpha: 0.85) // Red disk
            : const Color(0xFFFB8C00).withValues(alpha: 0.85) // Amber near finish
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 14),
        -math.pi / 2,
        sweepAngle,
        true,
        wedgePaint,
      );
    }

    // 5. Center pivot
    final pivotPaint = Paint()
      ..color = LhColors.brown
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, pivotPaint);
  }

  @override
  bool shouldRepaint(covariant _TimeTimerPainter oldDelegate) {
    return oldDelegate.fractionRemaining != fractionRemaining ||
        oldDelegate.isFinished != isFinished;
  }
}
