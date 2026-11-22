import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';
import '../models/quiz_set_model.dart';
import '../models/topic_model.dart';

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
  String query = '';

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
    notifyListeners();
  }

  Future<void> _attachToken() async {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để tải dữ liệu.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(token);
  }

  Future<void> loadCurrentUserCoins() async {
    try {
      await _attachToken();
      final profile = await _api.get('/me') as Map<String, dynamic>;
      coins = userCoins = (profile['coins'] as num?)?.toInt() ?? 0;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
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
