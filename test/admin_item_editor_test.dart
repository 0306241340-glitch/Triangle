import 'package:do_vui_ai_thuong/screens/admin/admin_edit_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('generates a structured editable item ID', (tester) async {
    Map<String, dynamic>? savedItem;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                savedItem = await showItemEditor(context);
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    final typeDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(typeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(typeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Danh hiệu').last);
    await tester.pumpAndSettle();

    final idField = _field('ID');
    final nameField = _field('Tên vật phẩm');
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Danh hiệu Cao thủ');
    await tester.pump();
    expect(
      tester.widget<TextField>(idField).controller!.text,
      'item_title_danh_hieu_cao_thu',
    );

    await tester.ensureVisible(idField);
    await tester.enterText(idField, 'item_title_master');
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Danh hiệu Cao thủ mới');
    final priceField = _field('Giá (xu)');
    await tester.ensureVisible(priceField);
    await tester.enterText(priceField, '150');
    final saveButton = find.widgetWithText(FilledButton, 'Lưu');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedItem?['id'], 'item_title_master');
    expect(savedItem?['type'], 'title');
    expect(savedItem?['name'], 'Danh hiệu Cao thủ mới');
  });
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);
