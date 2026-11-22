// ViewModel Trang chủ (S05) — TV1 An giữ.
// Gọi API lấy danh sách chủ đề; API chưa deploy thì dùng dữ liệu mẫu
// (3 chủ đề trong seed-data.json) để màn hình vẫn chạy demo được.
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/app_constants.dart';
import '../models/item_model.dart';
import '../models/topic_model.dart';
import '../services/store_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  bool isLoading = false;
  String? error;
  List<Topic> topics = [];
  String query = '';
  int coins = AppConstants.initialCoins;
  final Map<String, int> ownedItems = {};

  List<Topic> get filteredTopics {
    if (query.isEmpty) return topics;
    final q = query.toLowerCase();
    return topics.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> loadCurrentUserCoins() async {
    try {
      final catalog = await StoreService().loadCatalog();
      syncCatalog(catalog);
    } catch (error, stackTrace) {
      debugPrint('Không thể tải số dư cửa hàng từ máy chủ: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    notifyListeners();
  }

  void syncCatalog(StoreCatalog catalog) {
    final safeCoins = catalog.coins ?? coins;
    coins = safeCoins;
    ownedItems
      ..clear()
      ..addAll(catalog.ownedQuantities);
    notifyListeners();
  }

  void updateAfterPurchase(StoreItem item, int remainingCoins, int quantity) {
    coins = remainingCoins;
    ownedItems[item.id] = quantity;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await _api.get('/topics');
      final list = (data is Map ? data['topics'] : null) ?? data;
      topics = (list as List)
          .map((e) => Topic.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // API chưa deploy: dùng dữ liệu mẫu, app vẫn chạy được.
      topics = _mockTopics;
    }
    isLoading = false;
    notifyListeners();
  }

  static const _mockTopics = [
    Topic(
      id: 'toan',
      name: 'Toán học',
      description: 'Số học, đại số, tư duy logic',
      icon: '📐',
      questionCount: 10,
    ),
    Topic(
      id: 'lich-su',
      name: 'Lịch sử Việt Nam',
      description: 'Sự kiện, nhân vật lịch sử',
      icon: '📜',
      questionCount: 10,
    ),
    Topic(
      id: 'khoa-hoc',
      name: 'Khoa học',
      description: 'Vật lý, hóa học, sinh học',
      icon: '🔬',
      questionCount: 10,
    ),
  ];
}
