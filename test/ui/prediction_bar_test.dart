import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse/models/models.dart';
import 'package:lighthouse/ui/ai/prediction_bar.dart';

void main() {
  AACButton btn(String id, String label) {
    return AACButton(
      id: id,
      label: label,
      labelByLocale: {'en': label},
      type: AACButtonType.word,
      position: (row: 0, col: 0),
      category: 'needs',
      baseWeight: 1.0,
      voiceOut: label,
      voiceOutByLocale: {'en': label},
      iconUri: 'test.svg',
    );
  }

  testWidgets('PredictionBar renders candidate chips and allows explicit tap selection', (tester) async {
    final testBoard = AACBoard(
      schemaVersion: '1.0',
      boardId: 'test_board',
      boardName: 'Test Board',
      gridDimensions: (rows: 2, cols: 2),
      colorKey: {},
      buttons: [
        btn('i', 'I'),
        btn('want', 'Want'),
        btn('water', 'Water'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PredictionBar(board: testBoard),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AI icon is present
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

    // Verify at least one candidate chip is rendered
    expect(find.byType(ActionChip), findsWidgets);

    // Tapping a candidate chip commits it to the sentence bar
    final chip = find.byType(ActionChip).first;
    await tester.tap(chip);
    await tester.pumpAndSettle();

    // Verify chip was clickable without throwing errors
    expect(tester.takeException(), isNull);
  });
}
