// ViewModel Trang chủ (S05) — TV1 An giữ.
// Gọi API lấy danh sách chủ đề; API chưa deploy thì dùng dữ liệu mẫu
// (3 chủ đề trong seed-data.json) để màn hình vẫn chạy demo được.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';
import '../models/match_history_model.dart';
import '../models/quiz_history_model.dart';
import '../models/quiz_set_model.dart';
import '../models/topic_model.dart';
import '../services/store_service.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({ApiClient? api, FirebaseAuth? auth})
    : _api = api ?? ApiClient(),
      _auth = auth;

  final ApiClient _api;
  final FirebaseAuth? _auth;
  bool _disposed = false;

  void _notifyListenersSafely() {
    if (_disposed) return;

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Lấy Firebase ID Token và gắn vào API.
  Future<void> _attachToken() async {
    final user = _auth?.currentUser ?? FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    _api.setToken(token);
  }

  bool isLoading = false;
  String? error;
  String displayName = '';
  int userScore = 0;
  int userCoins = 100;
  int coins = 100;

  final Map<String, int> ownedItems = {};

  List<Topic> topics = [];
  Map<String, List<QuizSet>> quizSetsByTopic = {};

  String query = '';

  bool isQuizHistoryLoading = false;
  bool isMatchHistoryLoading = false;
  String? quizHistoryError;
  String? matchHistoryError;
  String? historyTopicFilter;

  List<QuizHistoryRecord> quizHistory = [];
  List<MatchHistoryRecord> matchHistory = [];

  QuizHistoryDetailRecord? selectedQuizHistory;
  MatchHistoryDetailRecord? selectedMatchHistory;

  bool isHistoryDetailLoading = false;
  String? historyDetailError;

  List<Topic> get filteredTopics {
    if (query.isEmpty) return topics;

    final normalized = query.toLowerCase();

    return topics.where((topic) {
      return topic.name.toLowerCase().contains(normalized) ||
          quizSetsForTopic(topic.id)
              .any((set) => set.title.toLowerCase().contains(normalized));
    }).toList();
  }

  List<QuizSet> quizSetsForTopic(String topicId) =>
      quizSetsByTopic[topicId] ?? [];

  void setQuery(String value) {
    query = value;
    _notifyListenersSafely();
  }

  Future<void> loadCurrentUserCoins() async {
    try {
      final danhMuc = await StoreService().loadCatalog();
      syncCatalog(danhMuc);
    } catch (error, stackTrace) {
      debugPrint('Không thể tải số dư cửa hàng từ máy chủ: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    _notifyListenersSafely();
  }

  Future<void> loadQuizHistory({String? topicId}) async {
    historyTopicFilter = topicId;
    isQuizHistoryLoading = true;
    quizHistoryError = null;
    _notifyListenersSafely();

    try {
      await _attachToken();

      final response = await _api.get(
        '/quiz/history',
        query: {if (topicId != null && topicId.isNotEmpty) 'topicId': topicId},
      ) as List;

      quizHistory = response
          .map(
            (item) => QuizHistoryRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      quizHistoryError = e.toString();
    } finally {
      isQuizHistoryLoading = false;
      _notifyListenersSafely();
    }
  }

  Future<void> loadMatchHistory() async {
    isMatchHistoryLoading = true;
    matchHistoryError = null;
    _notifyListenersSafely();

    try {
      await _attachToken();

      final response = await _api.get('/pvp/history') as List;

      matchHistory = response
          .map(
            (item) => MatchHistoryRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      matchHistoryError = e.toString();
    } finally {
      isMatchHistoryLoading = false;
      _notifyListenersSafely();
    }
  }

  Future<void> loadQuizHistoryDetail(String historyId) async {
    isHistoryDetailLoading = true;
    historyDetailError = null;
    selectedQuizHistory = null;
    selectedMatchHistory = null;
    _notifyListenersSafely();

    try {
      await _attachToken();

      final response = await _api.get(
        '/quiz/history/${Uri.encodeComponent(historyId)}',
      ) as Map<String, dynamic>;

      selectedQuizHistory = QuizHistoryDetailRecord.fromJson(response);
    } catch (e) {
      historyDetailError = e.toString();
    } finally {
      isHistoryDetailLoading = false;
      _notifyListenersSafely();
    }
  }

  Future<void> loadMatchHistoryDetail(String historyId) async {
    isHistoryDetailLoading = true;
    historyDetailError = null;
    selectedQuizHistory = null;
    selectedMatchHistory = null;
    _notifyListenersSafely();

    try {
      await _attachToken();

      final response = await _api.get(
        '/pvp/history/${Uri.encodeComponent(historyId)}',
      ) as Map<String, dynamic>;

      selectedMatchHistory = MatchHistoryDetailRecord.fromJson(response);
    } catch (e) {
      historyDetailError = e.toString();
    } finally {
      isHistoryDetailLoading = false;
      _notifyListenersSafely();
    }
  }

  void syncCatalog(StoreCatalog danhMuc) {
    final soXuAnToan = danhMuc.coins ?? coins;

    coins = soXuAnToan;
    userCoins = soXuAnToan;

    ownedItems
      ..clear()
      ..addAll(danhMuc.ownedQuantities);

    _notifyListenersSafely();
  }

  void updateAfterPurchase(StoreItem vatPham, int xuConLai, int soLuong) {
    coins = xuConLai;
    userCoins = xuConLai;
    ownedItems[vatPham.id] = soLuong;

    _notifyListenersSafely();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    _notifyListenersSafely();

    try {
      await _attachToken();

      final responses = await Future.wait([
        _api.get('/me'),
        _api.get('/topics'),
        _api.get('/quiz-sets'),
      ]);

      final profile = responses[0] as Map<String, dynamic>;

      displayName =
          (profile['displayName'] as String?)?.trim().isNotEmpty == true
          ? profile['displayName'] as String
          : 'Bạn';

      userScore = (profile['score'] as num?)?.toInt() ?? 0;

      coins = userCoins = (profile['coins'] as num?)?.toInt() ?? 0;

      topics = (responses[1] as List)
          .map((item) => Topic.fromJson(item as Map<String, dynamic>))
          .toList();

      final sets = (responses[2] as List)
          .map((item) => QuizSet.fromJson(item as Map<String, dynamic>))
          .toList();

      quizSetsByTopic = {};

      for (final set in sets) {
        quizSetsByTopic.putIfAbsent(set.topicId, () => []).add(set);
      }
    } catch (e) {
      error = e.toString();
      topics = [];
      quizSetsByTopic = {};
    } finally {
      isLoading = false;
      _notifyListenersSafely();
    }
  }
}
