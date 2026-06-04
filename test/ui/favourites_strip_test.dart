/// Home favourites strip widget (ADR 0013).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/state/state.dart';
import 'package:lighthouse/ui/ui.dart';

AACButton _btn(String id, String label, {String iconUri = ''}) =>
    AACButton.fromJson({
      'id': id,
      'label': label,
      'type': 'word',
      'voice_out': label.toLowerCase(),
      'position': {'row': 0, 'col': 0},
      'category': 'food',
      if (iconUri.isNotEmpty) 'icon_uri': iconUri,
    });

Widget _host(
  List<AACButton> favs,
  void Function(AACButton) onTap, {
  bool hideText = false,
  bool hideIcon = false,
}) {
  return ProviderScope(
    overrides: [
      homeFavouritesProvider.overrideWith((ref) async => favs),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: FavouritesStrip(
          onTap: onTap,
          // Mirrors the home board's color key so tiles color by category.
          colorKey: const {'food': '#FFD9A6'},
          hideText: hideText,
          hideIcon: hideIcon,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('hidden (zero height) when there are no favourites',
      (tester) async {
    await tester.pumpWidget(_host(const [], (_) {}));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    final box = tester.widget<SizedBox>(find.descendant(
      of: find.byType(FavouritesStrip),
      matching: find.byType(SizedBox).first,
    ));
    expect(box.height ?? 0, 0);
  });

  testWidgets('renders pinned favourites and taps route the button',
      (tester) async {
    AACButton? tapped;
    await tester.pumpWidget(
      _host([_btn('btn_food_apple', 'Apple')], (b) => tapped = b),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);

    // The tile is colored by its category (food -> orange), not white (#4).
    final tileMaterial = tester.widget<Material>(
      find
          .ancestor(of: find.text('Apple'), matching: find.byType(Material))
          .first,
    );
    expect(tileMaterial.color, const Color(0xFFFFD9A6));

    await tester.tap(find.text('Apple'));
    await tester.pump();
    expect(tapped?.id, 'btn_food_apple');
  });

  testWidgets('picture-only mode (hideText) hides the favourite label',
      (tester) async {
    await tester.pumpWidget(_host(
      [_btn('btn_food_apple', 'Apple', iconUri: 'assets/arasaac/food/apple.png')],
      (_) {},
      hideText: true,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Apple'), findsNothing);
    expect(find.byType(Image), findsOneWidget,
        reason: 'the pictogram remains in picture-only mode');
  });

  testWidgets('word-only mode (hideIcon) hides the favourite pictogram',
      (tester) async {
    await tester.pumpWidget(_host(
      [_btn('btn_food_apple', 'Apple', iconUri: 'assets/arasaac/food/apple.png')],
      (_) {},
      hideIcon: true,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing,
        reason: 'word-only mode must drop the favourite pictogram');
    expect(find.text('Apple'), findsOneWidget);
  });

  testWidgets('a pictogram-less favourite keeps its label in picture-only mode',
      (tester) async {
    // hideText would hide the label, but with no pictogram the tile would be
    // blank, so the label must survive (never-blank guard).
    await tester.pumpWidget(_host(
      [_btn('btn_food_apple', 'Apple')],
      (_) {},
      hideText: true,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Apple'), findsOneWidget);
  });
}
