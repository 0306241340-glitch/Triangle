import 'package:do_vui_ai_thuong/models/item_model.dart';
import 'package:do_vui_ai_thuong/screens/home_profile/store_screen.dart';
import 'package:do_vui_ai_thuong/services/store_service.dart';
import 'package:do_vui_ai_thuong/viewmodels/home_profile_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses item image URL and the Firestore lifeline code', () {
    final item = StoreItem.fromJson({
      'id': 'item_extra_time',
      'name': 'Thêm thời gian',
      'description': '',
      'type': 'help',
      'lifelineCode': 'extra_time',
      'price': 20,
      'imageUrl': 'https://example.com/extra-time.png',
    });

    expect(item.effect, 'extra_time');
    expect(item.imageUrl, 'https://example.com/extra-time.png');
  });

  testWidgets('updates the store from the backend purchase result', (
    tester,
  ) async {
    final service = _FakeStoreService();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScreen(service: service, homeVm: _FakeHomeViewModel()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('⏱️'), findsOneWidget);
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

  testWidgets('does not show mock products when the shop API is down', (
    tester,
  ) async {
    final service = _FakeStoreService()..loadError = Exception('HTTP 404');

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScreen(service: service, homeVm: _FakeHomeViewModel()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('50/50'), findsNothing);
    expect(find.text('Chưa tải được'), findsOneWidget);
    expect(
      find.textContaining('Không thể tải cửa hàng từ PostgreSQL'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Chi tiết'), findsNothing);
    expect(service.purchasedItemId, isEmpty);
  });
}

class _FakeStoreService implements StoreService {
  var purchasedItemId = '';
  Object? loadError;

  @override
  Future<Map<String, dynamic>> loadInventory() async => {
    'items': <Map<String, dynamic>>[],
    'userItems': <Map<String, dynamic>>[],
  };

  @override
  Future<void> setEquipped(String itemId, {required bool equipped}) async {}

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
          imageUrl: '⏱️',
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

class _FakeHomeViewModel extends HomeViewModel {
  @override
  Future<void> loadCurrentUserCoins() async {
    coins = 200;
  }
}
