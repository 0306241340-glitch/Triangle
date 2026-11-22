import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/friend_model.dart';

class FriendService {
  FriendService({ApiClient? api, FirebaseAuth? auth})
    : _api = api ?? ApiClient(baseUrl: ApiClient.vuongApiBaseUrl),
      _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _auth;

  String get currentUserId {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để quản lý bạn bè.');
    }
    return uid;
  }

  Future<void> _attachToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để quản lý bạn bè.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(token);
  }

  Future<void> ensurePublicProfile() async {
    await _attachToken();
    final profile = await _api.get('/me') as Map<String, dynamic>;
    if ((profile['userCode'] as String?)?.isNotEmpty != true) {
      throw StateError('Tài khoản chưa có mã kết bạn.');
    }
  }

  Future<List<PublicProfile>> searchUsers(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) {
      throw ArgumentError('Nhập ít nhất 2 ký tự để tìm bạn bè.');
    }
    await _attachToken();
    final result =
        await _api.get('/friends/search', query: {'q': normalized}) as List;
    return result
        .map((item) => PublicProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequest>> loadFriends() async {
    await _attachToken();
    final rows = await _api.get('/friends') as List;
    return rows
        .map(
          (item) => FriendRequest.fromJson(
            (item as Map<String, dynamic>)['id'].toString(),
            item,
          ),
        )
        .toList();
  }

  Future<List<FriendRequest>> loadRequests({required bool incoming}) async {
    await _attachToken();
    final rows = await _api.get(
      '/friends/requests',
      query: {'direction': incoming ? 'incoming' : 'outgoing'},
    ) as List;
    return rows
        .map(
          (item) => FriendRequest.fromJson(
            (item as Map<String, dynamic>)['id'].toString(),
            item,
          ),
        )
        .toList();
  }

  Future<PublicProfile?> getPublicProfile(String uid) async {
    await _attachToken();
    try {
      final result = await _api.get('/friends/profile/$uid');
      return PublicProfile.fromJson(result as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> sendRequest(String recipientUid) async {
    await _attachToken();
    await _api.post('/friends/$recipientUid', {});
  }

  Future<void> acceptRequest(String requestId) async {
    await _attachToken();
    await _api.post('/friends/$requestId/accept', {});
  }

  Future<void> rejectRequest(String requestId) => _delete(requestId);

  Future<void> removeFriend(String requestId) => _delete(requestId);

  Future<void> cancelRequest(String requestId) => _delete(requestId);

  Future<void> _delete(String requestId) async {
    await _attachToken();
    await _api.delete('/friends/$requestId');
  }
}
