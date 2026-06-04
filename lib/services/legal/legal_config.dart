/// Legal / policy link configuration.
///
/// Compile-time URL for the app's hosted privacy policy, baked into the build
/// like the OTA and feedback endpoints. Empty by default, which keeps the
/// in-app "Privacy policy" entry dead-UI-gated (hidden) until the page exists,
/// so a parent never taps a link that 404s.
///
/// The destination is DECIDED: `https://kinderhorizon.org/lighthouse/privacy`
/// (a dedicated, app-scoped policy, separate from the donation `/privacy`).
/// The const stays empty until the website coder publishes that page; the
/// launch build then sets it:
///   `flutter build --dart-define=PRIVACY_POLICY_URL=https://kinderhorizon.org/lighthouse/privacy`.
/// The same URL goes in the App Store "App Privacy" / Play "Data Safety" forms.
library;

const String kLighthousePrivacyPolicyUrl =
    String.fromEnvironment('PRIVACY_POLICY_URL', defaultValue: '');
