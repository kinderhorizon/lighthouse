/// The channel to board files the phone hands to Lighthouse (ADR 0015
/// amendment). Tests override it with a fake channel.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/services.dart';

final incomingBoardFilesProvider = Provider<IncomingBoardFiles>(
  (ref) => IncomingBoardFiles(),
);
