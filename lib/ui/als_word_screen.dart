/// Aided Language Stimulation (ALS) view.
///
/// In ALS mode, the device does NOT speak. Instead, it shows the
/// selected word in very large text and waits for the parent to voice
/// it aloud. Tap anywhere to dismiss. See ADR 0004 § Voice-output
/// behavior.
library;

import 'package:flutter/material.dart';

class ALSWordScreen extends StatelessWidget {
  const ALSWordScreen({
    required this.text,
    super.key,
  });

  final String text;

  static Future<void> show(BuildContext context, {required String text}) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => ALSWordScreen(text: text),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 120),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 120,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
