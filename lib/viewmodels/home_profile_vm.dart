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
      id: 'topic_tong_hop',
      name: 'Kiến thức tổng hợp / Đời sống',
      description: 'Các câu hỏi xoay quanh sự vật, hiện tượng tự nhiên, khoa học thường thức và xã hội.',
      icon: '🌍',
      questionCount: 10,
    ),
    Topic(
      id: 'topic_do_meo',
      name: 'Đố dân gian & Câu đố mẹo',
      description: 'Các câu đố chữ, câu đố mẹo thử thách tư duy nhanh nhạy, chơi chữ và hài hước.',
      icon: '🧩',
      questionCount: 10,
    ),
    Topic(
      id: 'topic_giai_tri',
      name: 'Giải trí – Âm nhạc – Phim ảnh',
      description: 'Kiến thức về các bộ phim nổi tiếng, ca sĩ, diễn viên, bài hát hoặc các chương trình truyền hình.',
      icon: '🎬',
      questionCount: 10,
    ),
  ];
}
