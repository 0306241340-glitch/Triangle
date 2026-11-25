import 'package:do_vui_ai_thuong/services/friend_service.dart';
import 'package:do_vui_ai_thuong/services/pvp_social_service.dart';
import 'package:do_vui_ai_thuong/viewmodels/pvp_social_vm.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePvpSocialService implements PvpSocialService {
  String? maBanBeDuocMoi;

  @override
  Future<String> inviteFriend(String maBanBe) async {
    maBanBeDuocMoi = maBanBe;
    return 'room-123';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFriendService implements FriendService {
  @override
  String get currentUserId => 'player-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns the room so the inviter can join the waiting match', () async {
    final dichVuPvp = _FakePvpSocialService();
    final boDieuKhien = PvpSocialViewModel(
      pvpService: dichVuPvp,
      friendService: _FakeFriendService(),
    );
    addTearDown(boDieuKhien.dispose);

    final ketQua = await boDieuKhien.inviteFriend('friend-1');

    expect(dichVuPvp.maBanBeDuocMoi, 'friend-1');
    expect(ketQua.maPhong, 'room-123');
    expect(ketQua.thongBao, isNull);
  });
}
