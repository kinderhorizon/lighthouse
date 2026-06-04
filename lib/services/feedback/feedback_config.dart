/// Feedback configuration (ADR 0018).
///
/// Compile-time endpoint, empty by default so the feature is dormant until the
/// Azure Function is deployed (empty -> the client returns `notConfigured`).
/// Set at build time: `flutter build --dart-define=FEEDBACK_URL=https://...`.
library;

const String kFeedbackEndpointUrl =
    String.fromEnvironment('FEEDBACK_URL', defaultValue: '');
