import 'package:do_vui_ai_thuong/widgets/item_visual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the same fallback for matching item codes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            ItemVisual(imageUrl: '', type: 'help', code: 'extra_time'),
            ItemVisual(imageUrl: '', type: 'help', itemId: 'item_extra_time'),
          ],
        ),
      ),
    );

    expect(find.text('⏱️'), findsNWidgets(2));
  });
}
