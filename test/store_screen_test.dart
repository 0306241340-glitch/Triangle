import 'package:do_vui_ai_thuong/models/item_model.dart';
import 'package:do_vui_ai_thuong/screens/home_profile/store_screen.dart';
import 'package:do_vui_ai_thuong/services/store_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the catalog and updates the balance after purchase', (
    tester,
  ) async {
    final service = _FakeStoreService();

    await tester.pumpWidget(MaterialApp(home: StoreScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('200 xu'), findsOneWidget);
    expect(find.text('50/50'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Khung avatar Vàng'),
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('Khung avatar Vàng'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chi tiết').first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Mua')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Mua')),
    );
    await tester.pumpAndSettle();

    expect(service.purchasedItemId, 'item_5050');
    expect(find.text('170 xu'), findsOneWidget);
    expect(find.textContaining('Đang có: 1'), findsOneWidget);
  });

  testWidgets('shows preview catalog and blocks purchase when API is down', (
    tester,
  ) async {
    final service = _FakeStoreService()..loadError = Exception('HTTP 404');

    await tester.pumpWidget(MaterialApp(home: StoreScreen(service: service)));
    await tester.pumpAndSettle();

    expect(find.text('50/50'), findsOneWidget);
    expect(find.text('30 xu'), findsOneWidget);
    expect(find.text('Chưa tải được'), findsOneWidget);
    expect(
      find.textContaining('Máy chủ cửa hàng hiện chưa khả dụng'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Khung avatar Vàng'),
      300,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(find.text('Khung avatar Vàng'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chi tiết').first);
    await tester.pumpAndSettle();
    expect(find.text('Giá: 30 xu'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Mua')),
    );
    await tester.pumpAndSettle();

    expect(service.purchasedItemId, isEmpty);
    expect(
      find.text('API cửa hàng chưa hoạt động. Chưa thực hiện giao dịch.'),
      findsOneWidget,
    );
  });
}

class _FakeStoreService implements StoreService {
  var purchasedItemId = '';
  Object? loadError;

  @override
  Future<StoreCatalog> loadCatalog() async {
    if (loadError != null) throw loadError!;
    return const StoreCatalog(
      coins: 200,
      items: [
        StoreItem(
          id: 'item_5050',
          name: '50/50',
          description: 'Loại hai đáp án sai.',
          type: 'help',
          effect: 'fifty_fifty',
          price: 30,
        ),
        StoreItem(
          id: 'item_frame_gold',
          name: 'Khung avatar Vàng',
          description: 'Khung avatar màu vàng.',
          type: 'frame',
          effect: '',
          price: 100,
        ),
      ],
      ownedQuantities: {},
    );
  }

  @override
  Future<StorePurchaseResult> purchase(String itemId) async {
    purchasedItemId = itemId;
    return const StorePurchaseResult(coins: 170, quantity: 1);
  }
}
