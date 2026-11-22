import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/match_queue_model.dart';
import '../models/notification_model.dart';
import '../models/room_model.dart';

class PvpSocialService {
  PvpSocialService({ApiClient? api, FirebaseAuth? auth})
    : _api = api ?? ApiClient(baseUrl: ApiClient.vuongApiBaseUrl),
      _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _auth;

  String get currentUserId {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Bạn cần đăng nhập để tham gia đấu 1vs1.');
    }
    return uid;
  }

  Future<void> _attachToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để tham gia đấu 1vs1.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(token);
  }

  Future<MatchQueueState> joinQueue() async {
    await _attachToken();
    final result = await _api.post('/pvp/queue', {});
    return MatchQueueState.fromJson(result as Map<String, dynamic>);
  }

  Future<MatchQueueState> queueStatus() async {
    await _attachToken();
    final result = await _api.get('/pvp/queue');
    return MatchQueueState.fromJson(result as Map<String, dynamic>);
  }

  Future<void> leaveQueue() async {
    await _attachToken();
    await _api.delete('/pvp/queue');
  }

  Future<String> inviteFriend(String friendUid) async {
    await _attachToken();
    final result = await _api.post(
      '/pvp/invite/${Uri.encodeComponent(friendUid)}',
      {},
    ) as Map<String, dynamic>;
    return result['roomId'] as String;
  }

  Future<List<PvpInvitation>> loadInvitations() async {
    await _attachToken();
    final result = await _api.get('/pvp/invitations') as List;
    return result
        .map((item) => PvpInvitation.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> acceptInvitation(String roomId) async {
    await _attachToken();
    await _api.post('/pvp/rooms/${Uri.encodeComponent(roomId)}/accept', {});
  }

  Future<void> declineInvitation(String roomId) async {
    await _attachToken();
    await _api.post('/pvp/rooms/${Uri.encodeComponent(roomId)}/decline', {});
  }

  Future<PvpRoom> loadRoom(String roomId) async {
    await _attachToken();
    final result = await _api.get('/pvp/rooms/${Uri.encodeComponent(roomId)}');
    return PvpRoom.fromJson(result as Map<String, dynamic>);
  }

  Future<PvpRoom> submitAnswer({
    required String roomId,
    required int questionIndex,
    required int selectedIndex,
  }) async {
    await _attachToken();
    final result = await _api.post(
      '/pvp/rooms/${Uri.encodeComponent(roomId)}/answer',
      {'questionIndex': questionIndex, 'selectedIndex': selectedIndex},
    );
    return PvpRoom.fromJson(result as Map<String, dynamic>);
  }
}
