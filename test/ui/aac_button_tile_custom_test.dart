/// AACButtonTile image source: asset vs file path (ADR 0012).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/ui.dart';

AACButton _button({required String iconUri, String category = 'food'}) =>
    AACButton.fromJson({
      'id': 'btn_x',
      'label': 'Cup',
      'type': 'word',
      'voice_out': 'cup',
      'position': {'row': 0, 'col': 0},
      'category': category,
      'icon_uri': iconUri,
    });

Widget _host(AACButton button) => MaterialApp(
      home: Scaffold(
        body: AACButtonTile(
          button: button,
          colorKey: const {'food': '#FFD9A6', 'custom': '#FFFFFF'},
          onTap: () {},
        ),
      ),
    );

void main() {
  testWidgets('a bundled asset path renders via AssetImage', (tester) async {
    await tester.pumpWidget(
      _host(_button(iconUri: 'assets/arasaac/food/apple.png')),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
  });

  testWidgets('an absolute file path renders via FileImage (custom button)',
      (tester) async {
    await tester.pumpWidget(
      _host(_button(iconUri: '/data/custom_images/cup.png', category: 'custom')),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
    // The word is still shown even though the file does not exist on disk.
    expect(find.text('Cup'), findsOneWidget);
  });
}
