/// In-app soft restart (ADR 0017).
///
/// Re-mounts the whole app subtree below this widget by swapping a UniqueKey,
/// which disposes and recreates the [ProviderScope] underneath it, so every
/// keepAlive provider re-initializes exactly as on a cold launch. Used right
/// after an OTA content update is applied: the corrected boards / pictograms /
/// clips are already on disk, but the running app cached the old ones at
/// startup, so the change only shows once the content is re-read.
///
/// This is NOT an OS process restart. iOS does not allow an app to terminate
/// and relaunch itself (it reads as a crash to the user and is an App Store
/// rejection reason), so a literal relaunch is impossible there. Re-mounting
/// the root achieves the same visible effect (content re-read from disk) and is
/// store-safe on both platforms. It only ever runs on a parent's explicit tap
/// in Settings, never under the child mid-session.
library;

import 'package:flutter/widgets.dart';

class RestartWidget extends StatefulWidget {
  const RestartWidget({required this.child, super.key});

  final Widget child;

  /// Re-mounts the nearest enclosing [RestartWidget]'s subtree. Safe to call
  /// from anywhere below it (e.g. the "Show the update now" button after an
  /// OTA apply). A no-op if there is no [RestartWidget] ancestor.
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
