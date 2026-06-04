/// AACButtonTile hide-text (symbol-only) mode.
///
/// Clinician setting (default off): hiding the text label leaves a
/// pictogram-only grid. The word must still be exposed to screen readers via
/// the Semantics label, and a tile with no pictogram must keep its text rather
/// than render blank (unusable for a non-speaking child).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/ui.dart';

AACButton _button({String iconUri = 'assets/arasaac/pronouns/i.png'}) {
  return AACButton.fromJson({
    'id': 'btn_test',
    'label': 'Want',
    'type': 'word',
    'voice_out': 'want',
    'position': {'row': 0, 'col': 0},
    'category': 'verb',
    'icon_uri': iconUri,
  });
}

Widget _host(AACButton button,
    {bool hideText = false, bool hideIcon = false}) {
  return MaterialApp(
    home: Scaffold(
      body: AACButtonTile(
        button: button,
        colorKey: const {'verb': '#C2FFC2'},
        hideText: hideText,
        hideIcon: hideIcon,
        onTap: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('text shows by default (hideText false)', (tester) async {
    await tester.pumpWidget(_host(_button(), hideText: false));
    expect(find.text('Want'), findsOneWidget);
  });

  testWidgets('text is hidden when hideText is true', (tester) async {
    await tester.pumpWidget(_host(_button(), hideText: true));
    expect(find.text('Want'), findsNothing);
  });

  testWidgets('Semantics still exposes the word when text is hidden',
      (tester) async {
    await tester.pumpWidget(_host(_button(), hideText: true));
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Want',
      ),
      findsWidgets,
      reason: 'hiding visual text must not hide the word from screen readers',
    );
  });

  testWidgets('a tile with no pictogram keeps its text even when hidden',
      (tester) async {
    await tester.pumpWidget(_host(_button(iconUri: ''), hideText: true));
    expect(find.text('Want'), findsOneWidget,
        reason: 'a blank tile (no icon, no text) is unusable');
  });

  testWidgets('pictogram shows by default (hideIcon false)', (tester) async {
    await tester.pumpWidget(_host(_button()));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('pictogram is hidden when hideIcon is true', (tester) async {
    await tester.pumpWidget(_host(_button(), hideIcon: true));
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('the word still shows when the pictogram is hidden',
      (tester) async {
    // Text-only mode: the label must remain so the tile is never blank.
    await tester.pumpWidget(_host(_button(), hideIcon: true));
    expect(find.text('Want'), findsOneWidget);
  });
}
