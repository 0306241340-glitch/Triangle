import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../core/api_client.dart';
import '../models/friend_model.dart';
import '../models/match_queue_model.dart';
import '../models/notification_model.dart';
import '../models/room_model.dart';
import '../services/friend_service.dart';
import '../services/pvp_social_service.dart';

class PvpActionResult {
  const PvpActionResult({this.maPhong, this.thongBao});

  final String? maPhong;
  final String? thongBao;
}

class PvpSocialViewModel extends ChangeNotifier {
  PvpSocialViewModel({
    PvpSocialService? pvpService,
    FriendService? friendService,
  }) : dichVuPvp = pvpService ?? PvpSocialService(),
       dichVuBanBe = friendService ?? FriendService();

  final PvpSocialService dichVuPvp;
  final FriendService dichVuBanBe;

  bool _daHuy = false;
  StreamSubscription<MatchQueueState>? _langNgheHangDoi;
  Completer<PvpActionResult>? _choKetQuaTimTran;
  Future<MatchQueueState>? _yeuCauTimTran;
  final Map<String, Future<PublicProfile?>> _hoSoDaTai = {};

  bool dangTimTran = false;
  String? idDangXuLy;
  String? loiDongBoLoiMoi;
  late Future<List<FriendRequest>> dsBanBe;
  late Stream<List<PvpInvitation>> luongLoiMoi;

  void init() {
    dsBanBe = dichVuBanBe.loadFriends();
    luongLoiMoi = dichVuPvp.watchInvitations();
    _syncInvitations();
  }

  void _baoThayDoiAnToan() {
    if (_daHuy) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_daHuy) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _daHuy = true;
    final choKetQua = _choKetQuaTimTran;
    if (choKetQua != null && !choKetQua.isCompleted) {
      choKetQua.complete(const PvpActionResult());
    }
    _langNgheHangDoi?.cancel();
    super.dispose();
  }

  String get maNguoiDung => dichVuBanBe.currentUserId;

  Future<PublicProfile?> getProfile(String maNguoiDung) {
    return _hoSoDaTai.putIfAbsent(
      maNguoiDung,
      () => dichVuBanBe.getPublicProfile(maNguoiDung),
    );
  }

  void reloadFriends() {
    dsBanBe = dichVuBanBe.loadFriends();
    _baoThayDoiAnToan();
  }

  void reloadInvitations() {
    if (_daHuy) return;
    luongLoiMoi = dichVuPvp.watchInvitations();
    _baoThayDoiAnToan();
    _syncInvitations();
  }

  void _syncInvitations() {
    unawaited(() async {
      if (_daHuy) return;
      try {
        await dichVuPvp.syncInvitations();
        if (_daHuy) return;
        loiDongBoLoiMoi = null;
      } catch (loi) {
        if (_daHuy) return;
        loiDongBoLoiMoi = loi is ApiException ? loi.message : loi.toString();
      }
      _baoThayDoiAnToan();
    }());
  }

  Future<PvpActionResult> startQueue() async {
    if (dangTimTran || _daHuy) return const PvpActionResult();
    dangTimTran = true;
    _baoThayDoiAnToan();
    final choKetQua = Completer<PvpActionResult>();
    _choKetQuaTimTran = choKetQua;
    try {
      _langNgheHangDoi = dichVuPvp.watchQueue().listen(
        (hangDoi) {
          if (choKetQua.isCompleted || hangDoi.roomId == null) return;
          choKetQua.complete(PvpActionResult(maPhong: hangDoi.roomId));
        },
        onError: (Object loi) {
          if (!choKetQua.isCompleted) {
            choKetQua.complete(
              const PvpActionResult(
                thongBao: 'Mất kết nối realtime. Vui lòng thử lại.',
              ),
            );
          }
        },
        onDone: () {
          if (!choKetQua.isCompleted && dangTimTran) {
            choKetQua.complete(
              const PvpActionResult(
                thongBao: 'Kết nối realtime đã đóng. Vui lòng thử lại.',
              ),
            );
          }
        },
      );
      final yeuCauTimTran = dichVuPvp.joinQueue();
      _yeuCauTimTran = yeuCauTimTran;
      final hangDoi = await yeuCauTimTran;
      if (!dangTimTran || _daHuy) return const PvpActionResult();
      if (hangDoi.roomId != null) {
        return PvpActionResult(maPhong: hangDoi.roomId);
      }
      if (hangDoi.status == 'cancelled') {
        return const PvpActionResult(thongBao: 'Tìm trận đã bị hủy.');
      }
      final ketQua = await choKetQua.future;
      if (ketQua.thongBao != null) {
        try {
          await dichVuPvp.leaveQueue();
        } catch (_) {
          return PvpActionResult(
            thongBao: '${ketQua.thongBao} Không thể hủy hàng chờ trên máy chủ.',
          );
        }
      }
      return ketQua;
    } on ApiException catch (loi) {
      if (loi.statusCode == 409) {
        try {
          final phongHienTai = await dichVuPvp.queueStatus();
          if (phongHienTai.roomId != null) {
            return PvpActionResult(maPhong: phongHienTai.roomId);
          }
        } catch (_) {}
      }
      return PvpActionResult(thongBao: loi.message);
    } catch (_) {
      return const PvpActionResult(
        thongBao: 'Không thể tìm trận. Vui lòng thử lại.',
      );
    } finally {
      await _langNgheHangDoi?.cancel();
      _langNgheHangDoi = null;
      _yeuCauTimTran = null;
      if (identical(_choKetQuaTimTran, choKetQua)) {
        _choKetQuaTimTran = null;
      }
      dangTimTran = false;
      _baoThayDoiAnToan();
    }
  }

  Future<PvpActionResult> cancelQueue() async {
    dangTimTran = false;
    final choKetQua = _choKetQuaTimTran;
    if (choKetQua != null && !choKetQua.isCompleted) {
      choKetQua.complete(const PvpActionResult());
    }
    await _langNgheHangDoi?.cancel();
    _langNgheHangDoi = null;
    _baoThayDoiAnToan();
    try {
      final yeuCauDangChay = _yeuCauTimTran;
      if (yeuCauDangChay != null) {
        try {
          final hangDoi = await yeuCauDangChay;
          if (hangDoi.roomId != null) {
            return PvpActionResult(maPhong: hangDoi.roomId);
          }
        } catch (_) {}
      }
      await dichVuPvp.leaveQueue();
      return const PvpActionResult();
    } catch (_) {
      return const PvpActionResult(thongBao: 'Không thể hủy tìm trận.');
    }
  }

  Future<PvpActionResult> inviteFriend(String maBanBe) async {
    if (idDangXuLy != null) return const PvpActionResult();
    idDangXuLy = maBanBe;
    _baoThayDoiAnToan();
    try {
      final maPhong = await dichVuPvp.inviteFriend(maBanBe);
      return PvpActionResult(maPhong: maPhong);
    } on ApiException catch (loi) {
      if (loi.statusCode == 409) {
        try {
          final phongHienTai = await dichVuPvp.queueStatus();
          if (phongHienTai.roomId != null) {
            return PvpActionResult(maPhong: phongHienTai.roomId);
          }
        } catch (_) {}
      }
      return PvpActionResult(thongBao: loi.message);
    } catch (_) {
      return const PvpActionResult(
        thongBao: 'Không thể gửi lời mời thách đấu.',
      );
    } finally {
      idDangXuLy = null;
      _baoThayDoiAnToan();
    }
  }

  Future<PvpActionResult> respondToInvitation(
    PvpInvitation loiMoi, {
    required bool chapNhan,
  }) async {
    if (idDangXuLy != null) return const PvpActionResult();
    idDangXuLy = loiMoi.roomId;
    _baoThayDoiAnToan();
    try {
      if (chapNhan) {
        await dichVuPvp.acceptInvitation(loiMoi.roomId);
        reloadInvitations();
        return PvpActionResult(maPhong: loiMoi.roomId);
      }
      await dichVuPvp.declineInvitation(loiMoi.roomId);
      reloadInvitations();
      return const PvpActionResult(thongBao: 'Đã từ chối lời mời.');
    } on ApiException catch (loi) {
      return PvpActionResult(thongBao: loi.message);
    } catch (_) {
      return const PvpActionResult(thongBao: 'Không thể xử lý lời mời.');
    } finally {
      idDangXuLy = null;
      _baoThayDoiAnToan();
    }
  }

  Future<PvpActionResult> copyMyFriendCode() async {
    try {
      final hoSo = await dichVuBanBe.loadMyProfile();
      if (hoSo.userCode.isEmpty) {
        return const PvpActionResult(thongBao: 'Chưa có mã kết bạn.');
      }
      return PvpActionResult(thongBao: hoSo.userCode);
    } catch (_) {
      return const PvpActionResult(thongBao: 'Không thể chia sẻ mã kết bạn.');
    }
  }
}

class PvpRoomViewModel extends ChangeNotifier {
  PvpRoomViewModel({required String roomId, PvpSocialService? service})
    : maPhong = roomId,
      dichVu = service ?? PvpSocialService();

  final String maPhong;
  final PvpSocialService dichVu;

  bool _daHuy = false;
  bool _dangTaiPhong = false;
  bool _daThuTaiBangApi = false;
  DateTime? _lanTaiLaiHetGio;
  StreamSubscription<PvpRoom>? _langNghePhong;
  Timer? _dongHoDem;

  PvpRoom? phong;
  bool dangTai = true;
  bool dangGuiDapAn = false;
  bool dangHuy = false;
  int? luaChonDaChon;
  String? loi;

  String get maNguoiDung => dichVu.currentUserId;

  void init() {
    _langNghePhong = dichVu
        .watchRoom(maPhong)
        .listen(
          (phongMoi) {
            if (_daHuy) return;
            if (phong?.questionIndex != phongMoi.questionIndex) {
              _lanTaiLaiHetGio = null;
            }
            phong = phongMoi;
            loi = null;
            dangTai = false;
            if (phongMoi.status == 'finished' ||
                phongMoi.status == 'cancelled') {
              _dongHoDem?.cancel();
            }
            _baoThayDoiAnToan();
          },
          onError: (Object loi) {
            if (_daHuy) return;
            this.loi = loi is ApiException ? loi.message : loi.toString();
            dangTai = false;
            _baoThayDoiAnToan();
            if (!_daThuTaiBangApi &&
                loi is StateError &&
                loi.message ==
                    'Không tìm thấy dữ liệu realtime của trận đấu.') {
              _daThuTaiBangApi = true;
              loadRoom();
            }
          },
        );
    _dongHoDem = Timer.periodic(const Duration(seconds: 1), (_) {
      final phongHienTai = phong;
      if (_daHuy || phongHienTai?.status != 'playing') return;
      _baoThayDoiAnToan();
      final gioBatDau = phongHienTai?.questionStartTime;
      final bayGio = DateTime.now().toUtc();
      if (gioBatDau != null &&
          !bayGio.isBefore(
            gioBatDau.add(Duration(seconds: phongHienTai!.questionSeconds)),
          ) &&
          (_lanTaiLaiHetGio == null ||
              bayGio.difference(_lanTaiLaiHetGio!) >=
                  const Duration(seconds: 3))) {
        _lanTaiLaiHetGio = bayGio;
        loadRoom();
      }
    });
  }

  void _baoThayDoiAnToan() {
    if (_daHuy) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_daHuy) notifyListeners();
      });
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _daHuy = true;
    _langNghePhong?.cancel();
    _dongHoDem?.cancel();
    super.dispose();
  }

  Future<void> loadRoom() async {
    if (_dangTaiPhong || _daHuy) return;
    _dangTaiPhong = true;
    try {
      final phongMoi = await dichVu.loadRoom(maPhong);
      if (_daHuy) return;
      if (phong?.questionIndex != phongMoi.questionIndex) {
        _lanTaiLaiHetGio = null;
      }
      phong = phongMoi;
      loi = null;
      if (phongMoi.status == 'finished' || phongMoi.status == 'cancelled') {
        _dongHoDem?.cancel();
      }
    } catch (loi) {
      if (_daHuy) return;
      this.loi = loi is ApiException ? loi.message : loi.toString();
    } finally {
      _dangTaiPhong = false;
      dangTai = false;
      _baoThayDoiAnToan();
    }
  }

  Future<String?> cancelInvitation() async {
    final phongHienTai = phong;
    if (phongHienTai == null ||
        phongHienTai.status != 'waiting' ||
        phongHienTai.hostId != maNguoiDung ||
        dangHuy ||
        _daHuy) {
      return null;
    }

    dangHuy = true;
    _baoThayDoiAnToan();
    try {
      await dichVu.cancelInvitation(maPhong);
      await loadRoom();
      return null;
    } on ApiException catch (loi) {
      return loi.message;
    } catch (_) {
      return 'Không thể hủy lời mời.';
    } finally {
      dangHuy = false;
      _baoThayDoiAnToan();
    }
  }

  Future<String?> submitAnswer(int chiSoLuaChon) async {
    final phongHienTai = phong;
    if (phongHienTai == null ||
        phongHienTai.question == null ||
        phongHienTai.myAnswered ||
        dangGuiDapAn ||
        _daHuy) {
      return null;
    }
    dangGuiDapAn = true;
    luaChonDaChon = chiSoLuaChon;
    _baoThayDoiAnToan();
    try {
      phong = await dichVu.submitAnswer(
        maPhong: phongHienTai.id,
        chiSoCau: phongHienTai.questionIndex,
        chiSoDaChon: chiSoLuaChon,
      );
      return null;
    } catch (loi) {
      await loadRoom();
      return loi is ApiException
          ? loi.message
          : 'Không thể gửi đáp án. Vui lòng thử lại.';
    } finally {
      dangGuiDapAn = false;
      luaChonDaChon = null;
      _baoThayDoiAnToan();
    }
  }
}
