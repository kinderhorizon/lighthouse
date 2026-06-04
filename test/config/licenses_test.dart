/// The non-package licences registered for the in-app "Open-source licences"
/// page (Atkinson Hyperlegible, Cairo, Google Cloud TTS), with bodies loaded
/// from bundled assets.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/config/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers the three bundled licences with asset-loaded bodies',
      () async {
    registerBundledLicenses();

    final byPackage = <String, String>{};
    await for (final LicenseEntry e in LicenseRegistry.licenses) {
      final body = e.paragraphs.map((p) => p.text).join('\n');
      for (final pkg in e.packages) {
        byPackage[pkg] = body;
      }
    }

    expect(
      byPackage.keys,
      containsAll(
          ['Atkinson Hyperlegible', 'Cairo', 'Google Cloud Text-to-Speech']),
    );
    // Bodies came from the real assets, not a placeholder.
    expect(byPackage['Atkinson Hyperlegible'],
        contains('SIL Open Font License'));
    expect(byPackage['Cairo'], contains('SIL Open Font License'));
    expect(byPackage['Google Cloud Text-to-Speech'],
        contains('Google Cloud Text-to-Speech'));
  });
}
