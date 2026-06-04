/// RestartWidget (ADR 0017): re-mounts its subtree so a soft restart re-runs
/// child initState exactly as a cold launch would. Proven by giving the child
/// per-mount state and showing a restart() resets it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/ui/widgets/restart_widget.dart';

/// A child that counts how many times it has been initialized (mounted).
class _MountCounter extends StatefulWidget {
  const _MountCounter();
  @override
  State<_MountCounter> createState() => _MountCounterState();
}

class _MountCounterState extends State<_MountCounter> {
  static int initCount = 0;
  @override
  void initState() {
    super.initState();
    initCount++;
  }

  @override
  Widget build(BuildContext context) => Text('mount $initCount',
      textDirection: TextDirection.ltr);
}

void main() {
  testWidgets('restart() re-mounts the subtree (fresh initState)',
      (tester) async {
    _MountCounterState.initCount = 0;

    late BuildContext childContext;
    await tester.pumpWidget(
      RestartWidget(
        child: Builder(builder: (context) {
          childContext = context;
          return const _MountCounter();
        }),
      ),
    );

    expect(_MountCounterState.initCount, 1);

    RestartWidget.restart(childContext);
    await tester.pump();

    // The child was disposed and a new instance initialized: a real re-mount,
    // which is what forces every keepAlive provider to re-read content on apply.
    expect(_MountCounterState.initCount, 2);
  });

  testWidgets('restart() is a safe no-op with no RestartWidget ancestor',
      (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(Builder(builder: (context) {
      ctx = context;
      return const SizedBox.shrink();
    }));
    // Must not throw.
    RestartWidget.restart(ctx);
    await tester.pump();
  });
}
