/// AACButtonTile folder affordance.
///
/// Folders open a sub-board of more words. A corner badge (Icons.folder_rounded)
/// makes that affordance explicit, since the dog-ear corner radius alone reads
/// as decoration. Word tiles must NOT carry the badge. The badge is excluded
/// from semantics so it does not compete with the folder's button label.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/ui.dart';

AACButton _button({required String type}) {
  return AACButton.fromJson({
    'id': 'btn_test',
    'label': 'Food',
    'type': type,
    'voice_out': 'food',
    'position': {'row': 0, 'col': 0},
    'category': 'food_nav',
    'icon_uri': 'assets/arasaac/nav/food.png',
  });
}

Widget _host(AACButton button) {
  return MaterialApp(
    home: Scaffold(
      body: AACButtonTile(
        button: button,
        colorKey: const {'food_nav': '#FFD9A6'},
        onTap: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('folder tile shows the "more" affordance badge', (tester) async {
    await tester.pumpWidget(_host(_button(type: 'folder')));
    expect(
      find.byIcon(Icons.folder_rounded),
      findsOneWidget,
      reason: 'a folder must signal that it opens more words',
    );
  });

  testWidgets('word tile shows no folder badge', (tester) async {
    await tester.pumpWidget(_host(_button(type: 'word')));
    expect(find.byIcon(Icons.folder_rounded), findsNothing);
  });

  testWidgets('folder still announces its label as a button', (tester) async {
    await tester.pumpWidget(_host(_button(type: 'folder')));
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Food',
      ),
      findsWidgets,
    );
  });
}
