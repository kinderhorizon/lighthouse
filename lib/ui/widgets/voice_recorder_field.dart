/// Optional "record your own voice" control for the add-a-tile flows (the clinical lead
/// r4: every add-a-button flow should let a parent record their own audio for
/// the new tile, at the moment of creation, not only as a later edit).
///
/// Self-contained: owns an [AudioRecorder], records to a temp `.m4a`, and
/// reports the recorded clip File via [onChanged] (null when cleared). Unlike
/// the editor's re-record sheet, this does NOT persist the clip; the new
/// button's id does not exist until Save, so the caller imports the reported
/// clip under that id afterwards (via `customVoiceProvider.save`). Same encoder
/// and 15s cap as the editor sheet so recordings are consistent.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../l10n/app_localizations.dart';

/// Lets the host form finalize an in-progress recording at Save time. Without
/// this, tapping the form's "Save" while the parent is still recording (they
/// never tapped Stop) would silently drop the clip: the recorder only reports
/// via [VoiceRecorderField.onChanged] when it stops, so a never-stopped
/// recording is never saved. A recording for a non-speaking child must never be
/// silently lost, so the host calls [finalize] before reading the clip.
class VoiceRecorderController {
  _VoiceRecorderFieldState? _state;

  /// Stops an in-progress recording (if any) and returns the current clip, or
  /// null if nothing was recorded. Safe to call when idle or already stopped.
  Future<File?> finalize() async => _state?.finalizeAndGet() ?? Future.value();
}

class VoiceRecorderField extends StatefulWidget {
  const VoiceRecorderField({
    required this.idHint,
    required this.onChanged,
    this.controller,
    super.key,
  });

  /// A short hint used only for the temp filename (e.g. the target board id);
  /// the final button id does not exist yet.
  final String idHint;

  /// Reports the freshly recorded clip, or null when the parent clears it.
  final ValueChanged<File?> onChanged;

  /// Optional handle so the host can finalize an in-progress recording when the
  /// parent taps Save without tapping Stop first (see [VoiceRecorderController]).
  final VoiceRecorderController? controller;

  @override
  State<VoiceRecorderField> createState() => _VoiceRecorderFieldState();
}

enum _Phase { idle, recording, recorded }

class _VoiceRecorderFieldState extends State<VoiceRecorderField> {
  final AudioRecorder _recorder = AudioRecorder();
  _Phase _phase = _Phase.idle;
  Timer? _timer;
  int _secs = 0;
  String? _path;

  static const int _maxSecs = 15;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(VoiceRecorderField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) oldWidget.controller!._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  /// Finalizes an in-progress recording (so a never-stopped clip is still
  /// captured at Save) and returns the current clip, or null if none. Called by
  /// [VoiceRecorderController.finalize].
  Future<File?> finalizeAndGet() async {
    if (_phase == _Phase.recording) await _stop();
    final p = _path;
    return p == null ? null : File(p);
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.editVoiceMicDenied)),
        );
      }
      return;
    }
    final safe = widget.idHint.replaceAll(RegExp('[^a-zA-Z0-9_]'), '');
    final path = '${Directory.systemTemp.path}/lh_voice_new_${safe}_'
        '${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _phase = _Phase.recording;
      _secs = 0;
      _path = path;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs++);
      if (_secs >= _maxSecs) _stop();
    });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final stopped = await _recorder.stop();
    if (!mounted) return;
    final clipPath = stopped ?? _path;
    setState(() => _phase = _Phase.recorded);
    widget.onChanged(clipPath == null ? null : File(clipPath));
  }

  void _clear() {
    final path = _path;
    if (path != null) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {/* best-effort temp cleanup */}
    }
    setState(() {
      _phase = _Phase.idle;
      _secs = 0;
      _path = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_phase) {
      case _Phase.idle:
        return OutlinedButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.mic_none_rounded),
          label: Text(l10n.recordVoiceOptional),
        );
      case _Phase.recording:
        return Row(
          children: [
            FilledButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: Text(l10n.recordVoiceStop),
            ),
            const SizedBox(width: 12),
            Text('$_secs/$_maxSecs s'),
          ],
        );
      case _Phase.recorded:
        return Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.recordVoiceRecorded)),
            TextButton(
              onPressed: _start,
              child: Text(l10n.editActionRerecordVoice),
            ),
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.recordVoiceClear,
            ),
          ],
        );
    }
  }
}
