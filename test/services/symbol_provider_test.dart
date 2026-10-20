/// Tests for the SymbolProvider architecture.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/services/symbols/symbols.dart';

void main() {
  group('SymbolProvider Architecture Tests', () {
    test('FileSymbolProvider identifies and handles local files', () {
      const provider = FileSymbolProvider();
      expect(provider.canHandle('/data/user/0/app/custom.png'), isTrue);
      expect(provider.canHandle('assets/symbols/food.png'), isFalse);
      expect(provider.canHandle(''), isFalse);
      expect(provider.id, 'file');
    });

    test('AssetSymbolProvider identifies and handles bundled assets', () {
      const provider = AssetSymbolProvider();
      expect(provider.canHandle('assets/symbols/verbs/want.png'), isTrue);
      expect(provider.canHandle('/storage/emulated/0/pic.jpg'), isFalse);
      expect(provider.license, 'Apache-2.0');
      expect(provider.id, 'asset');
    });

    test('VectorSymbolProvider resolves semantic icons correctly', () {
      const provider = VectorSymbolProvider();
      expect(provider.canHandle('any_uri'), isTrue);
      expect(VectorSymbolProvider.resolveIcon('eat'), Icons.restaurant);
      expect(VectorSymbolProvider.resolveIcon('drink'), Icons.local_drink);
      expect(VectorSymbolProvider.resolveIcon('bathroom'), Icons.wc);
      expect(VectorSymbolProvider.resolveIcon('home'), Icons.home);
      expect(VectorSymbolProvider.resolveIcon('help'), Icons.help);
      expect(VectorSymbolProvider.resolveIcon('happy'), Icons.sentiment_satisfied_alt);
    });

    testWidgets('CompositeSymbolProvider renders asset and vector symbols', (tester) async {
      final composite = CompositeSymbolProvider.defaultInstance;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    composite.buildSymbol(
                      context,
                      uri: 'assets/symbols/verbs/want.png',
                      label: 'Want',
                      width: 48,
                      height: 48,
                    ),
                    composite.buildSymbol(
                      context,
                      uri: 'unknown_custom_key',
                      label: 'Eat',
                      width: 48,
                      height: 48,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
