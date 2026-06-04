/// Services barrel.
///
/// Platform-bridging services: TTS (see docs/adr/0004-tts-strategy.md),
/// crash logger (see docs/adr/0002-no-automatic-telemetry.md, Phase 1 with
/// backup exclusion), board loader, share helper, file-import handler
/// (Pack Loader, Phase 1 follow-up).
library;

export 'board_loader.dart';
export 'board_pack_exporter.dart';
export 'board_pack_importer.dart';
export 'board_registry.dart';
export 'crash/crash.dart';
export 'custom/custom_button_store.dart';
export 'feedback/feedback.dart';
export 'favourites/favourites_store.dart';
export 'layout/board_layout_store.dart';
export 'layout/hidden_tiles_store.dart';
export 'layout/icon_override_store.dart';
export 'legal/legal_config.dart';
export 'voice/custom_voice_player.dart';
export 'voice/custom_voice_store.dart';
export 'network/network.dart';
export 'onboarding/onboarding.dart';
export 'ota/ota.dart';
export 'settings/settings.dart';
export 'tts/bundled_audio_tts_engine.dart';
export 'tts/fallback_tts_engine.dart';
export 'tts/piper_tts_engine.dart';
export 'tts/system_tts_engine.dart';
export 'tts/tts_engine.dart';
