import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/friend_model.dart';

class FriendService {
  FriendService({ApiClient? api, FirebaseAuth? auth})
    : _api = api ?? ApiClient(),
      _dangNhap = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _dangNhap;

  String get currentUserId {
    final maNguoiDung = _dangNhap.currentUser?.uid;
    if (maNguoiDung == null) {
      throw StateError('Bạn cần đăng nhập để quản lý bạn bè.');
    }
    return maNguoiDung;
  }

  Future<void> _ganToken() async {
    final nguoiDung = _dangNhap.currentUser;
    if (nguoiDung == null) {
      throw StateError('Bạn cần đăng nhập để quản lý bạn bè.');
    }

    final maToken = await nguoiDung.getIdToken();
    if (maToken == null || maToken.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }

    _api.setToken(maToken);
  }

  Future<void> ensurePublicProfile() async {
    await loadMyProfile();
  }

  Future<PublicProfile> loadMyProfile() async {
    await _ganToken();
    final duLieu = await _api.get('/me') as Map<String, dynamic>;
    final hoSo = PublicProfile.fromJson(duLieu);

    if (hoSo.userCode.isEmpty) {
      throw StateError('Tài khoản chưa có mã kết bạn.');
    }

    return hoSo;
  }

  Future<List<PublicProfile>> searchUsers(String tuKhoa) async {
    final tuKhoaChuanHoa = tuKhoa.trim();

    if (tuKhoaChuanHoa.length < 2) {
      throw ArgumentError('Nhập ít nhất 2 ký tự để tìm bạn bè.');
    }

    await _ganToken();

    final ketQua =
        await _api.get('/friends/search', query: {'q': tuKhoaChuanHoa}) as List;

    return ketQua
        .map((duLieu) => PublicProfile.fromJson(duLieu as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequest>> loadFriends() async {
    await _ganToken();

    final dsBan = await _api.get('/friends') as List;

    return dsBan.map((duLieu) {
      final yeuCau = duLieu as Map<String, dynamic>;
      return FriendRequest.fromJson(yeuCau['id'].toString(), yeuCau);
    }).toList();
  }

  Future<List<FriendRequest>> loadRequests({required bool laLoiMoiDen}) async {
    await _ganToken();

    final dsLoiMoi = await _api.get(
      '/friends/requests',
      query: {'direction': laLoiMoiDen ? 'incoming' : 'outgoing'},
    ) as List;

    return dsLoiMoi.map((duLieu) {
      final yeuCau = duLieu as Map<String, dynamic>;
      return FriendRequest.fromJson(yeuCau['id'].toString(), yeuCau);
    }).toList();
  }

  Future<PublicProfile?> getPublicProfile(String maNguoiDung) async {
    await _ganToken();

    try {
      final ketQua = await _api.get('/friends/profile/$maNguoiDung');
      return PublicProfile.fromJson(ketQua as Map<String, dynamic>);
    } on ApiException catch (loi) {
      if (loi.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> sendRequest(String maNguoiNhan) async {
    await _ganToken();
    await _api.post('/friends/$maNguoiNhan', {});
  }

  Future<void> acceptRequest(String maYeuCau) async {
    await _ganToken();
    await _api.post('/friends/$maYeuCau/accept', {});
  }

  Future<void> rejectRequest(String maYeuCau) => _xoaYeuCau(maYeuCau);

  Future<void> removeFriend(String maYeuCau) => _xoaYeuCau(maYeuCau);

  Future<void> cancelRequest(String maYeuCau) => _xoaYeuCau(maYeuCau);

  Future<void> _xoaYeuCau(String maYeuCau) async {
    await _ganToken();
    await _api.delete('/friends/$maYeuCau');
  }
}
