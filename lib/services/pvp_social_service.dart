import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/api_client.dart';
import '../models/match_queue_model.dart';
import '../models/notification_model.dart';
import '../models/room_model.dart';

class PvpSocialService {
  PvpSocialService({
    ApiClient? api,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _api = api ?? ApiClient(),
       _dangNhap = auth ?? FirebaseAuth.instance,
       _duLieuRealtime = firestore ?? FirebaseFirestore.instance;

  final ApiClient _api;
  final FirebaseAuth _dangNhap;
  final FirebaseFirestore _duLieuRealtime;

  String get currentUserId {
    final maNguoiDung = _dangNhap.currentUser?.uid;
    if (maNguoiDung == null) {
      throw StateError('Bạn cần đăng nhập để tham gia đấu 1vs1.');
    }
    return maNguoiDung;
  }

  Future<void> _ganToken() async {
    final nguoiDung = _dangNhap.currentUser;
    if (nguoiDung == null) {
      throw StateError('Bạn cần đăng nhập để tham gia đấu 1vs1.');
    }
    final maToken = await nguoiDung.getIdToken();
    if (maToken == null || maToken.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(maToken);
  }

  Future<MatchQueueState> joinQueue() async {
    await _ganToken();
    final ketQua = await _api.post('/pvp/queue', {});
    return MatchQueueState.fromJson(ketQua as Map<String, dynamic>);
  }

  Future<MatchQueueState> queueStatus() async {
    await _ganToken();
    final ketQua = await _api.get('/pvp/queue');
    return MatchQueueState.fromJson(ketQua as Map<String, dynamic>);
  }

  Stream<MatchQueueState> watchQueue() {
    final maNguoiDung = currentUserId;
    return _duLieuRealtime
        .collection('users')
        .doc(maNguoiDung)
        .collection('pvp_state')
        .doc('current')
        .snapshots()
        .map((banGhi) {
          final duLieu = banGhi.data();
          return MatchQueueState.fromJson(duLieu ?? {'status': 'idle'});
        });
  }

  Future<void> leaveQueue() async {
    await _ganToken();
    await _api.delete('/pvp/queue');
  }

  Future<String> inviteFriend(String maBanBe) async {
    await _ganToken();
    final ketQua = await _api.post(
      '/pvp/invite/${Uri.encodeComponent(maBanBe)}',
      {},
    ) as Map<String, dynamic>;
    return ketQua['roomId'] as String;
  }

  Stream<List<PvpInvitation>> watchInvitations() {
    final maNguoiDung = currentUserId;
    return _duLieuRealtime
        .collection('users')
        .doc(maNguoiDung)
        .collection('pvp_invitations')
        .snapshots()
        .map((banGhi) {
          final dsLoiMoi = banGhi.docs.map((taiLieu) {
            final duLieu = Map<String, dynamic>.from(taiLieu.data());
            duLieu['roomId'] ??= taiLieu.id;
            duLieu['notificationId'] ??= taiLieu.id;
            final ngayTao = duLieu['createdAt'];
            if (ngayTao is Timestamp) {
              duLieu['createdAt'] = ngayTao.toDate().toIso8601String();
            }
            return PvpInvitation.fromJson(duLieu);
          }).toList();
          dsLoiMoi.sort((loiMoiA, loiMoiB) {
            final ngayA = loiMoiA.createdAt;
            final ngayB = loiMoiB.createdAt;
            if (ngayA == null) return 1;
            if (ngayB == null) return -1;
            return ngayB.compareTo(ngayA);
          });
          return dsLoiMoi;
        });
  }

  Future<void> acceptInvitation(String maPhong) async {
    await _ganToken();
    await _api.post('/pvp/rooms/${Uri.encodeComponent(maPhong)}/accept', {});
  }

  Future<void> declineInvitation(String maPhong) async {
    await _ganToken();
    await _api.post('/pvp/rooms/${Uri.encodeComponent(maPhong)}/decline', {});
  }

  Future<void> cancelInvitation(String maPhong) async {
    await _ganToken();
    await _api.post('/pvp/rooms/${Uri.encodeComponent(maPhong)}/cancel', {});
  }

  Future<void> syncInvitations() async {
    await _ganToken();
    await _api.get('/pvp/invitations');
  }

  Future<PvpRoom> loadRoom(String maPhong) async {
    await _ganToken();
    final ketQua = await _api.get('/pvp/rooms/${Uri.encodeComponent(maPhong)}');
    return PvpRoom.fromJson(ketQua as Map<String, dynamic>);
  }

  Stream<PvpRoom> watchRoom(String maPhong) {
    final maNguoiDung = currentUserId;
    return _duLieuRealtime.collection('rooms').doc(maPhong).snapshots().map((
      banGhi,
    ) {
      final duLieuTho = banGhi.data();
      if (duLieuTho == null) {
        throw StateError('Không tìm thấy dữ liệu realtime của trận đấu.');
      }
      final duLieu = Map<String, dynamic>.from(duLieuTho);
      final gioBatDauTho = duLieu['questionStartTime'];
      if (gioBatDauTho is Timestamp) {
        duLieu['questionStartTime'] = gioBatDauTho.toDate().toIso8601String();
      }
      final dsDaTraLoi = (duLieu['answeredUids'] as List? ?? [])
          .whereType<String>()
          .toSet();
      final maChuPhong = duLieu['hostId'] as String;
      final maKhach = duLieu['guestId'] as String?;
      final maDoiThu = maNguoiDung == maChuPhong ? maKhach : maChuPhong;
      duLieu['myAnswered'] = dsDaTraLoi.contains(maNguoiDung);
      duLieu['opponentAnswered'] =
          maDoiThu != null && dsDaTraLoi.contains(maDoiThu);
      return PvpRoom.fromJson(duLieu);
    });
  }

  Future<PvpRoom> submitAnswer({
    required String maPhong,
    required int chiSoCau,
    required int chiSoDaChon,
  }) async {
    await _ganToken();
    final ketQua = await _api.post(
      '/pvp/rooms/${Uri.encodeComponent(maPhong)}/answer',
      {'questionIndex': chiSoCau, 'selectedIndex': chiSoDaChon},
    );
    return PvpRoom.fromJson(ketQua as Map<String, dynamic>);
  }
}
