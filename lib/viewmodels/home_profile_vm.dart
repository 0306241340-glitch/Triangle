// ViewModel Trang chủ (S05) — TV1 An giữ.
// Gọi API lấy danh sách chủ đề; API chưa deploy thì dùng dữ liệu mẫu
// (3 chủ đề trong seed-data.json) để màn hình vẫn chạy demo được.
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/topic_model.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  bool isLoading = false;
  String? error;
  List<Topic> topics = [];
  String query = '';

  List<Topic> get filteredTopics {
    if (query.isEmpty) return topics;
    final q = query.toLowerCase();
    return topics.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  void setQuery(String value) {
    query = value;
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
