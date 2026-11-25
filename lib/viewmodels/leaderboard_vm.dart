import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../core/api_client.dart';
import '../models/leaderboard_model.dart';

// Token Firebase sống 1 tiếng. Ép làm mới (getIdToken(true)) mỗi lần
// bấm tab sẽ gọi mạng thêm 1-2 giây nên tab bị "đơ". Chỉ làm mới khi
// token đã gần hết hạn (50 phút); nếu server trả 401 thì làm mới rồi
// gọi lại 1 lần.
String? _cachedToken;
DateTime? _cachedAt;

Future<void> _attachToken(ApiClient api, {bool forceRefresh = false}) async {
  final now = DateTime.now();
  if (forceRefresh ||
      _cachedToken == null ||
      _cachedAt == null ||
      now.difference(_cachedAt!).inMinutes >= 50) {
    _cachedToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    _cachedAt = now;
  }
  api.setToken(_cachedToken);
}

class LeaderboardViewModel extends ChangeNotifier {
  LeaderboardViewModel({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  bool _disposed = false;
  bool isLoading = false;
  String? error;
  String scope = 'all';
  List<LeaderboardEntry> entries = [];
  int? myRank;
  int myScore = 0;

  String? get myUid => FirebaseAuth.instance.currentUser?.uid;

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

  Future<void> load([String nextScope = 'all', String? topicId]) async {
    if (_disposed) return;
    scope = nextScope;
    isLoading = true;
    error = null;
    _notifyListenersSafely();
    try {
      await _fetch(scope, topicId);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token hết hạn thật: lấy token mới rồi gọi lại 1 lần.
        try {
          await _fetch(scope, topicId, forceRefresh: true);
        } on ApiException catch (e2) {
          error = e2.message;
        } catch (_) {
          error = 'Không tải được bảng xếp hạng, thử lại sau';
        }
      } else {
        error = e.message;
      }
    } catch (_) {
      error = 'Không tải được bảng xếp hạng, thử lại sau';
    }
    isLoading = false;
    _notifyListenersSafely();
  }

  Future<void> _fetch(
    String scope,
    String? topicId, {
    bool forceRefresh = false,
  }) async {
    await _attachToken(_api, forceRefresh: forceRefresh);
    final query = <String, String>{'scope': scope, 'limit': '20'};
    if (topicId != null) query['topicId'] = topicId;
    final data = await _api.get('/leaderboard', query: query);
    if (_disposed) return;
    final raw = data['entries'] as List? ?? [];
    entries = raw
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList();
    myRank = (data['myRank'] as num?)?.toInt();
    myScore = (data['myScore'] as num?)?.toInt() ?? 0;
  }
}

class AdminStatsViewModel extends ChangeNotifier {
  AdminStatsViewModel({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  bool _disposed = false;
  bool isLoading = false;
  String? error;
  AdminStats? stats;

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

  Future<void> load() async {
    if (_disposed) return;
    isLoading = true;
    error = null;
    _notifyListenersSafely();
    try {
      await _attachToken(_api);
      final data = await _api.get('/admin/stats');
      stats = AdminStats.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      // 403 = tài khoản hiện tại không có role admin
      error = e.statusCode == 403
          ? 'Chỉ quản trị viên mới xem được mục này'
          : e.message;
    } catch (_) {
      error = 'Không tải được thống kê, thử lại sau';
    }
    isLoading = false;
    _notifyListenersSafely();
  }
}
