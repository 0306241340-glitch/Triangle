// ViewModel Trang chủ (S05) — TV1 An giữ.
// Gọi API lấy danh sách chủ đề; API chưa deploy thì dùng dữ liệu mẫu
// (3 chủ đề trong seed-data.json) để màn hình vẫn chạy demo được.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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

  bool isLoading = false;
  String? error;
  String displayName = '';
  int userScore = 0;
  int userCoins = 100;
  int coins = 100;
  final Map<String, int> ownedItems = {};
  List<Topic> topics = [];
  Map<String, List<QuizSet>> quizSetsByTopic = {};
  final Set<String> favoriteTopicIds = {};
  final Set<String> topicFavoriteRequests = {};
  String query = '';
  bool isQuizHistoryLoading = false;
  bool isMatchHistoryLoading = false;
  bool isLoadingTopicFavorites = false;
  String? topicFavoriteLoadError;
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

  bool isTopicFavorite(String topicId) => favoriteTopicIds.contains(topicId);

  bool isUpdatingTopicFavorite(String topicId) =>
      topicFavoriteRequests.contains(topicId);

  Future<String?> toggleTopicFavorite(String topicId) async {
    if (!topicFavoriteRequests.add(topicId)) return null;
    notifyListeners();
    try {
      await _attachToken();
      if (favoriteTopicIds.contains(topicId)) {
        await _api.delete(
          '/favorites',
          query: {'targetId': topicId, 'targetType': 'topic'},
        );
        favoriteTopicIds.remove(topicId);
      } else {
        await _api.post('/favorites', {
          'targetId': topicId,
          'targetType': 'topic',
        });
        favoriteTopicIds.add(topicId);
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      topicFavoriteRequests.remove(topicId);
      notifyListeners();
    }
  }

  Future<void> loadTopicFavorites() async {
    if (topics.isEmpty) {
      favoriteTopicIds.clear();
      return;
    }
    isLoadingTopicFavorites = true;
    topicFavoriteLoadError = null;
    notifyListeners();
    try {
      await _attachToken();
      final responses = await Future.wait(
        topics.map(
          (topic) => _api.get(
            '/favorites/status',
            query: {'targetId': topic.id, 'targetType': 'topic'},
          ),
        ),
      );
      favoriteTopicIds
        ..clear()
        ..addAll([
          for (var index = 0; index < topics.length; index++)
            if ((responses[index] as Map<String, dynamic>)['isFavorite'] ==
                true)
              topics[index].id,
        ]);
    } catch (e) {
      topicFavoriteLoadError = e.toString();
    } finally {
      isLoadingTopicFavorites = false;
      notifyListeners();
    }
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  Future<void> loadCurrentUserCoins() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      coins = AppConstants.initialCoins;
      notifyListeners();
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();
      final userCoins =
          (snapshot.data()?['coins'] as num?)?.toInt() ??
          AppConstants.initialCoins;
      coins = userCoins;
    } catch (_) {
      coins = AppConstants.initialCoins;
    }
    notifyListeners();
  }

  Future<void> loadQuizHistory({String? topicId}) async {
    historyTopicFilter = topicId;
    isQuizHistoryLoading = true;
    quizHistoryError = null;
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> loadMatchHistory() async {
    isMatchHistoryLoading = true;
    matchHistoryError = null;
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> loadQuizHistoryDetail(String historyId) async {
    isHistoryDetailLoading = true;
    historyDetailError = null;
    selectedQuizHistory = null;
    selectedMatchHistory = null;
    notifyListeners();
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
      notifyListeners();
    }
  }

  Future<void> loadMatchHistoryDetail(String historyId) async {
    isHistoryDetailLoading = true;
    historyDetailError = null;
    selectedQuizHistory = null;
    selectedMatchHistory = null;
    notifyListeners();
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
      notifyListeners();
    }
  }

  void syncCatalog(StoreCatalog catalog) {
    final safeCoins = catalog.coins ?? coins;
    coins = safeCoins;
    userCoins = safeCoins;
    ownedItems
      ..clear()
      ..addAll(catalog.ownedQuantities);
    notifyListeners();
  }

  void updateAfterPurchase(StoreItem item, int remainingCoins, int quantity) {
    coins = remainingCoins;
    userCoins = remainingCoins;
    ownedItems[item.id] = quantity;
    notifyListeners();
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
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
      await loadTopicFavorites();
    } catch (e) {
      error = e.toString();
      topics = [];
      quizSetsByTopic = {};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
