// ViewModel Trang chủ (S05) — TV1 An.
// Lấy dữ liệu thật từ Firestore (topics, quiz_sets, user info).
// Nếu Firestore lỗi, fallback mock để app vẫn chạy.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../models/quiz_set_model.dart';
import '../models/topic_model.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel();

  bool isLoading = false;
  String? error;

  // Dữ liệu user
  String displayName = '';
  int userScore = 0;
  int userCoins = AppConstants.initialCoins;

  // Danh sách chủ đề & bộ đề (từ Firestore)
  List<Topic> topics = [];
  // Map topicId -> danh sách QuizSet
  Map<String, List<QuizSet>> quizSetsByTopic = {};

  String query = '';

  List<Topic> get filteredTopics {
    if (query.isEmpty) return topics;
    final q = query.toLowerCase();
    return topics.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  List<QuizSet> quizSetsForTopic(String topicId) =>
      quizSetsByTopic[topicId] ?? [];

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;

    // ── 1. Thông tin user ──
    try {
      final uid = auth.currentUser?.uid;
      displayName = auth.currentUser?.displayName ?? 'Bạn';
      if (uid != null) {
        final snap =
            await db.collection(AppConstants.usersCollection).doc(uid).get();
        final d = snap.data();
        if (d != null) {
          userScore = (d['score'] as num?)?.toInt() ?? 0;
          userCoins = (d['coins'] as num?)?.toInt() ?? AppConstants.initialCoins;
          if ((d['displayName'] as String?)?.isNotEmpty == true) {
            displayName = d['displayName'] as String;
          }
        }
      }
    } catch (e) {
      debugPrint('[HomeVM] Lỗi load user: $e');
    }

    // ── 2. Danh sách Topics từ Firestore ──
    try {
      final snap = await db
          .collection(AppConstants.topicsCollection)
          .where('isActive', isEqualTo: true)
          .get();
      topics = snap.docs
          .map((d) => Topic.fromJson({...d.data(), 'id': d.id}))
          .toList();
      debugPrint('[HomeVM] Tải ${topics.length} topics từ Firestore');
    } catch (e) {
      debugPrint('[HomeVM] Lỗi load topics: $e — dùng mock');
      topics = _mockTopics;
    }

    // ── 3. QuizSets cho từng topic ──
    try {
      final snap = await db
          .collection(AppConstants.quizSetsCollection)
          .where('isActive', isEqualTo: true)
          .get();
      final allSets = snap.docs
          .map((d) => QuizSet.fromJson({...d.data(), 'id': d.id}))
          .toList();
      quizSetsByTopic = {};
      for (final qs in allSets) {
        quizSetsByTopic.putIfAbsent(qs.topicId, () => []).add(qs);
      }
      debugPrint('[HomeVM] Tải ${allSets.length} quiz_sets từ Firestore');
    } catch (e) {
      debugPrint('[HomeVM] Lỗi load quiz_sets: $e — dùng mock');
      quizSetsByTopic = _mockQuizSets;
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Mock fallback khi Firestore không trả dữ liệu ──
  static const _mockTopics = [
    Topic(
      id: 'topic_tong_hop',
      name: 'Kiến thức tổng hợp / Đời sống',
      description:
          'Các câu hỏi xoay quanh sự vật, hiện tượng tự nhiên, khoa học thường thức và xã hội.',
      icon: '🌍',
      questionCount: 10,
    ),
    Topic(
      id: 'topic_do_meo',
      name: 'Đố dân gian & Câu đố mẹo',
      description:
          'Các câu đố chữ, câu đố mẹo thử thách tư duy nhanh nhạy, chơi chữ và hài hước.',
      icon: '🧩',
      questionCount: 10,
    ),
    Topic(
      id: 'topic_giai_tri',
      name: 'Giải trí – Âm nhạc – Phim ảnh',
      description:
          'Kiến thức về các bộ phim nổi tiếng, ca sĩ, diễn viên, bài hát hoặc các chương trình truyền hình.',
      icon: '🎬',
      questionCount: 10,
    ),
  ];

  static final _mockQuizSets = <String, List<QuizSet>>{
    'topic_tong_hop': [
      const QuizSet(
        id: 'set_tong_hop_1',
        topicId: 'topic_tong_hop',
        title: 'Kiến thức tổng hợp / Đời sống — Bộ 1',
        description:
            '10 câu trắc nghiệm bao quát kiến thức đời sống, khoa học thường thức, địa lý và lịch sử.',
        level: 'medium',
        questionCount: 10,
        durationSec: 300,
        attemptCount: 1,
        avgScore: 50.0,
      ),
    ],
    'topic_do_meo': [
      const QuizSet(
        id: 'set_do_meo_1',
        topicId: 'topic_do_meo',
        title: 'Đố dân gian & Câu đố mẹo — Bộ 1',
        description:
            '10 câu đố chữ, câu đố dân gian hài hước thử thách trí tưởng tượng và sự nhanh nhạy.',
        level: 'easy',
        questionCount: 10,
        durationSec: 300,
        attemptCount: 0,
        avgScore: 0.0,
      ),
    ],
    'topic_giai_tri': [
      const QuizSet(
        id: 'set_giai_tri_1',
        topicId: 'topic_giai_tri',
        title: 'Giải trí – Âm nhạc – Phim ảnh — Bộ 1',
        description:
            '10 câu hỏi về các bộ phim kinh điển, ca khúc nổi tiếng, ca sĩ và các giải thưởng nghệ thuật.',
        level: 'medium',
        questionCount: 10,
        durationSec: 300,
        attemptCount: 0,
        avgScore: 0.0,
      ),
    ],
  };
}
