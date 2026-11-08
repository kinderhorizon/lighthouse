/// Board files the phone hands to Lighthouse ("Open with Lighthouse").
///
/// ADR 0015 amendment (2026-11-08): a parent who receives a shared board can
/// open the file straight into Lighthouse from Messages, Mail, AirDrop, Files,
/// WhatsApp, Quick Share and so on, instead of having to find Settings, Import
/// and then the file. Before this, the phone did not know Lighthouse opens
/// these files, so it offered them to other apps (cloud drives, office apps)
/// that asked the parent to sign in.
///
/// The native side (the iOS scene plugin in AppDelegate.swift, the Android
/// MainActivity) copies the incoming file into the app's temporary directory
/// (never backed up), at most [maxBytesHint] + 1 bytes, and keeps ONE pending
/// path; a newer file replaces an older one. Dart takes it with [takePending]
/// when the board screen is showing, asks the parent, and deletes the copy
/// after.
library;

import 'dart:async';

import 'package:flutter/services.dart';

class IncomingBoardFiles {
  IncomingBoardFiles({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'lighthouse/incoming_file';

  /// The native copy stops at this size + 1 byte, so an oversized file still
  /// arrives (and the loader rejects it with its own size check) without the
  /// app ever writing more than this. Mirrors [BoardLoader.maxFileBytes].
  static const int maxBytesHint = 4 * 1024 * 1024;

  final MethodChannel _channel;
  final StreamController<void> _arrivals = StreamController<void>.broadcast();
  bool _listening = false;

  /// Fires when the phone hands the RUNNING app a new file. A file that
  /// arrives before anyone listens stays pending for [takePending].
  Stream<void> get arrivals {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'fileReceived') _arrivals.add(null);
      });
    }
    return _arrivals.stream;
  }

  /// The path of the file waiting to be added, or null. Taking it clears it on
  /// the native side, so each file is offered once.
  Future<String?> takePending() async {
    try {
      return await _channel.invokeMethod<String>('takePendingFile');
    } on MissingPluginException {
      return null; // desktop / tests without the native side
    } on PlatformException {
      return null;
    }
  }
}
