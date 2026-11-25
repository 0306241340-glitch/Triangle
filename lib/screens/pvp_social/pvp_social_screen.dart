import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../models/friend_model.dart';
import '../../models/notification_model.dart';
import '../../models/room_model.dart';
import '../../services/friend_service.dart';
import '../../services/pvp_social_service.dart';
import '../home_profile/friends_screen.dart';

class PvpSocialScreen extends StatefulWidget {
  const PvpSocialScreen({super.key, this.service, this.friendService});

  final PvpSocialService? service;
  final FriendService? friendService;

  @override
  State<PvpSocialScreen> createState() => _PvpSocialScreenState();
}

class _PvpSocialScreenState extends State<PvpSocialScreen>
    with SingleTickerProviderStateMixin {
  static const _mauNen = Colors.white;
  static const _mauThe = Colors.white;
  static const _mauVien = Color(0xFFE5E7EB);
  static const _mauNenBieuTuong = Color(0xFFEFF4FF);
  static const _mauXanh = Color(0xFF5B82F6);
  static const _mauChuPhu = Color(0xFF667085);

  late final PvpSocialService _dichVuDau;
  late final FriendService _dichVuBanBe;
  late final TabController _boChuyenTab;
  late Future<List<FriendRequest>> _dsBanBe;
  late Future<List<PvpInvitation>> _dsLoiMoi;
  final Map<String, Future<PublicProfile?>> _hoSoBan = {};
  Timer? _boDemLoiMoi;
  bool _dangTimTran = false;
  String? _idDangXuLy;

  @override
  void initState() {
    super.initState();
    _dichVuDau = widget.service ?? PvpSocialService();
    _dichVuBanBe = widget.friendService ?? FriendService();
    _boChuyenTab = TabController(length: 3, vsync: this);
    _dsBanBe = _dichVuBanBe.loadFriends();
    _dsLoiMoi = _dichVuDau.loadInvitations();
    _boDemLoiMoi = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _taiLaiLoiMoi(),
    );
  }

  @override
  void dispose() {
    _boDemLoiMoi?.cancel();
    _boChuyenTab.dispose();
    super.dispose();
  }

  void _taiLaiBanBe() {
    setState(() {
      _dsBanBe = _dichVuBanBe.loadFriends();
    });
  }

  void _taiLaiLoiMoi() {
    if (mounted) {
      setState(() {
        _dsLoiMoi = _dichVuDau.loadInvitations();
      });
    }
  }

  Future<PublicProfile?> _taiHoSoBan(String idNguoiDung) {
    return _hoSoBan.putIfAbsent(
      idNguoiDung,
      () => _dichVuBanBe.getPublicProfile(idNguoiDung),
    );
  }

  Future<void> _timTranNgauNhien() async {
    if (_dangTimTran) return;
    setState(() => _dangTimTran = true);
    try {
      var hangDoi = await _dichVuDau.joinQueue();
      while (mounted && _dangTimTran) {
        if (hangDoi.roomId != null) {
          await _moPhong(hangDoi.roomId!);
          break;
        }
        if (hangDoi.status == 'cancelled') {
          throw StateError('Tìm trận đã bị hủy.');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || !_dangTimTran) break;
        hangDoi = await _dichVuDau.queueStatus();
      }
    } catch (loi) {
      if (mounted && _dangTimTran) _hienThongBao(loi.toString());
    } finally {
      if (mounted) setState(() => _dangTimTran = false);
    }
  }

  Future<void> _huyTimTran() async {
    setState(() => _dangTimTran = false);
    try {
      await _dichVuDau.leaveQueue();
    } catch (loi) {
      if (mounted) _hienThongBao(loi.toString());
    }
  }

  Future<void> _thachDauBan(String idBan) async {
    setState(() => _idDangXuLy = idBan);
    try {
      await _dichVuDau.inviteFriend(idBan);
      if (mounted) _hienThongBao('Đã gửi lời mời thách đấu.');
    } catch (loi) {
      if (mounted) _hienThongBao(loi.toString());
    } finally {
      if (mounted) setState(() => _idDangXuLy = null);
    }
  }

  Future<void> _phanHoiLoiMoi(
    PvpInvitation loiMoi, {
    required bool chapNhan,
  }) async {
    setState(() => _idDangXuLy = loiMoi.roomId);
    try {
      if (chapNhan) {
        await _dichVuDau.acceptInvitation(loiMoi.roomId);
        await _moPhong(loiMoi.roomId);
      } else {
        await _dichVuDau.declineInvitation(loiMoi.roomId);
        if (mounted) _hienThongBao('Đã từ chối lời mời.');
      }
      _taiLaiLoiMoi();
    } catch (loi) {
      if (mounted) _hienThongBao(loi.toString());
    } finally {
      if (mounted) setState(() => _idDangXuLy = null);
    }
  }

  Future<void> _moPhong(String maPhong) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PvpRoomScreen(roomId: maPhong, service: _dichVuDau),
      ),
    );
    if (mounted) _taiLaiLoiMoi();
  }

  void _hienThongBao(String noiDung) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(noiDung)));
  }

  void _moDanhSachBanBe({required int tab}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => FriendsScreen(initialTab: tab),
          ),
        )
        .then((_) {
          if (mounted) _taiLaiBanBe();
        });
  }

  Future<void> _saoChepMaBanBe() async {
    try {
      final hoSo = await _dichVuBanBe.loadMyProfile();
      if (hoSo.userCode.isEmpty) {
        throw StateError('Chưa có mã kết bạn để chia sẻ.');
      }
      await Clipboard.setData(ClipboardData(text: hoSo.userCode));
      if (mounted) _hienThongBao('Đã sao chép mã kết bạn.');
    } catch (loi) {
      if (mounted) {
        _hienThongBao('Không thể chia sẻ mã kết bạn: $loi');
      }
    }
  }

  void _moTabThachBan() {
    _boChuyenTab.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mauNen,
      appBar: AppBar(
        backgroundColor: _mauNen,
        foregroundColor: const Color(0xFF1F2937),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text('Đấu 1 vs 1'),
        bottom: TabBar(
          controller: _boChuyenTab,
          labelColor: _mauXanh,
          unselectedLabelColor: _mauChuPhu,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          indicatorColor: _mauXanh,
          indicatorWeight: 3,
          dividerColor: _mauVien,
          tabs: const [
            Tab(text: 'Đấu nhanh'),
            Tab(text: 'Thách bạn'),
            Tab(text: 'Lời mời'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _boChuyenTab,
        children: [_tabDauNhanh(), _tabThachBan(), _tabLoiMoi()],
      ),
    );
  }

  Widget _tabDauNhanh() {
    return ColoredBox(
      color: const Color(0xFFF5F7FC),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.sports_martial_arts_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Sẵn sàng so tài?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tìm người chơi có điểm số phù hợp với bạn.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 18),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ThongTinTran(
                      bieuTuong: Icons.quiz_outlined,
                      noiDung: '10 câu',
                    ),
                    _ThongTinTran(
                      bieuTuong: Icons.timer_outlined,
                      noiDung: '15 giây/câu',
                    ),
                    _ThongTinTran(
                      bieuTuong: Icons.star_outline,
                      noiDung: '10 điểm/câu',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _dangTimTran ? _huyTimTran : _timTranNgauNhien,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _dangTimTran
                        ? const Icon(Icons.close_rounded)
                        : const Icon(Icons.search_rounded),
                    label: Text(
                      _dangTimTran ? 'Hủy tìm trận' : 'Tìm trận ngay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_dangTimTran) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.24),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Đang tìm đối thủ... Bạn có thể hủy bất cứ lúc nào.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Luật chơi',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE0E6F2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _mauNenBieuTuong,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: _mauXanh,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: _mauChuPhu,
                              fontSize: 15,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(
                                text: 'Mỗi câu chỉ trả lời một lần. ',
                                style: TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: 'Đáp án đã chọn không sửa được.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE0E6F2)),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _mauNenBieuTuong,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          color: _mauXanh,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: _mauChuPhu,
                              fontSize: 15,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(
                                text: 'Hết 15 giây ',
                                style: TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'trận tự chuyển câu tiếp theo; câu chưa '
                                    'trả lời không được tính điểm.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabThachBan() {
    return FutureBuilder<List<FriendRequest>>(
      future: _dsBanBe,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _trangThaiLoi(
            'Không tải được danh sách bạn bè.',
            _taiLaiBanBe,
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _mauXanh),
          );
        }
        final banBe = snapshot.data!;
        if (banBe.isEmpty) {
          return _trangThaiTrong(
            bieuTuong: Icons.group_add_outlined,
            tieuDe: 'Chưa có bạn để thách đấu',
            moTa: 'Kết bạn trước rồi quay lại đây để cùng so tài nhé.',
            thaoTac: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: () => _moDanhSachBanBe(tab: 2),
                    style: FilledButton.styleFrom(
                      backgroundColor: _mauXanh,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tìm bạn bè',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _saoChepMaBanBe,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mauXanh,
                      backgroundColor: _mauThe,
                      side: const BorderSide(color: _mauVien, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Chia sẻ mã của tôi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _taiLaiBanBe(),
          color: _mauXanh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: banBe.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final quanHe = banBe[index];
              final idNguoiDung = quanHe.otherUserId(
                _dichVuBanBe.currentUserId,
              );
              return _theBanBe(idNguoiDung);
            },
          ),
        );
      },
    );
  }

  Widget _theBanBe(String idNguoiDung) {
    return FutureBuilder<PublicProfile?>(
      future: _taiHoSoBan(idNguoiDung),
      builder: (context, snapshot) {
        final hoSo = snapshot.data;
        final ten = hoSo?.displayName ?? 'Người chơi';
        final dangGui = _idDangXuLy == idNguoiDung;
        return Card(
          color: _mauThe,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: _mauVien),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                _anhDaiDien(ten, hoSo?.avatarUrl ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ten,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        snapshot.hasError
                            ? 'Chưa tải được thông tin'
                            : hoSo?.userCode.isNotEmpty == true
                            ? 'Mã bạn bè: ${hoSo!.userCode}'
                            : 'Sẵn sàng thách đấu',
                        style: const TextStyle(color: _mauChuPhu, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _idDangXuLy == null
                      ? () => _thachDauBan(idNguoiDung)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mauXanh,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 42),
                  ),
                  child: dangGui
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Thách đấu'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tabLoiMoi() {
    return FutureBuilder<List<PvpInvitation>>(
      future: _dsLoiMoi,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _trangThaiLoi(
            'Không tải được lời mời thách đấu.',
            _taiLaiLoiMoi,
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _mauXanh),
          );
        }
        final danhSachLoiMoi = snapshot.data!;
        if (danhSachLoiMoi.isEmpty) {
          return _trangThaiTrong(
            bieuTuong: Icons.mark_email_unread_outlined,
            tieuDe: 'Chưa có lời mời nào',
            moTa: 'Lời mời thách đấu từ bạn bè sẽ xuất hiện ở đây.',
            thaoTac: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _moTabThachBan,
                style: FilledButton.styleFrom(
                  backgroundColor: _mauXanh,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Thách đấu bạn bè',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _taiLaiLoiMoi(),
          color: _mauXanh,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: danhSachLoiMoi.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _theLoiMoi(danhSachLoiMoi[index]),
          ),
        );
      },
    );
  }

  Widget _theLoiMoi(PvpInvitation loiMoi) {
    final dangXuLy = _idDangXuLy == loiMoi.roomId;
    return Card(
      color: _mauThe,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _mauVien),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _anhDaiDien(
                  loiMoi.hostName,
                  '',
                  bieuTuong: Icons.sports_kabaddi_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loiMoi.hostName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Mời bạn đấu 10 câu hỏi',
                        style: TextStyle(color: _mauChuPhu, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: dangXuLy
                        ? null
                        : () => _phanHoiLoiMoi(loiMoi, chapNhan: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mauChuPhu,
                      side: const BorderSide(color: _mauVien),
                    ),
                    child: const Text('Từ chối'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _idDangXuLy == null
                        ? () => _phanHoiLoiMoi(loiMoi, chapNhan: true)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _mauXanh,
                      foregroundColor: Colors.white,
                    ),
                    child: dangXuLy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Chấp nhận'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _anhDaiDien(String ten, String duongDanAnh, {IconData? bieuTuong}) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: _mauNenBieuTuong,
      foregroundImage: duongDanAnh.startsWith('http')
          ? NetworkImage(duongDanAnh)
          : null,
      child: bieuTuong == null
          ? Text(
              ten.trim().isEmpty ? '?' : ten.trim().characters.first,
              style: const TextStyle(
                color: _mauXanh,
                fontWeight: FontWeight.bold,
              ),
            )
          : Icon(bieuTuong, color: _mauXanh),
    );
  }

  Widget _trangThaiTrong({
    required IconData bieuTuong,
    required String tieuDe,
    required String moTa,
    Widget? thaoTac,
  }) {
    return LayoutBuilder(
      builder: (context, rangBuoc) {
        final chieuCaoToiThieu = rangBuoc.maxHeight > 48
            ? rangBuoc.maxHeight - 48
            : 0.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: chieuCaoToiThieu,
              maxWidth: 420,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _mauNenBieuTuong,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(bieuTuong, size: 38, color: _mauXanh),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tieuDe,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    moTa,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _mauChuPhu,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  if (thaoTac != null) ...[const SizedBox(height: 24), thaoTac],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _trangThaiLoi(String noiDung, VoidCallback thuLai) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _mauChuPhu, size: 40),
            const SizedBox(height: 12),
            Text(
              noiDung,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF1F2937)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: thuLai,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _mauXanh,
                side: const BorderSide(color: _mauVien),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThongTinTran extends StatelessWidget {
  const _ThongTinTran({required this.bieuTuong, required this.noiDung});

  final IconData bieuTuong;
  final String noiDung;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(bieuTuong, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            noiDung,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PvpRoomScreen extends StatefulWidget {
  const PvpRoomScreen({required this.roomId, required this.service, super.key});

  final String roomId;
  final PvpSocialService service;

  @override
  State<PvpRoomScreen> createState() => _PvpRoomScreenState();
}

class _PvpRoomScreenState extends State<PvpRoomScreen> {
  PvpRoom? _phongDau;
  Timer? _boDemTaiPhong;
  Timer? _boDemHienThi;
  bool _dangTaiDuLieu = true;
  bool _dangTaiPhong = false;
  bool _dangGuiCauTraLoi = false;
  int? _luaChonDangGui;
  String? _loiTaiPhong;

  @override
  void initState() {
    super.initState();
    _taiPhong();
    _boDemTaiPhong = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _taiPhong(),
    );
    _boDemHienThi = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _phongDau?.status == 'playing') {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _boDemTaiPhong?.cancel();
    _boDemHienThi?.cancel();
    super.dispose();
  }

  Future<void> _taiPhong() async {
    if (_dangTaiPhong) return;
    _dangTaiPhong = true;
    try {
      final phong = await widget.service.loadRoom(widget.roomId);
      if (!mounted) return;
      setState(() {
        _phongDau = phong;
        _loiTaiPhong = null;
        _dangTaiDuLieu = false;
      });
      if (phong.status == 'finished' || phong.status == 'cancelled') {
        _boDemTaiPhong?.cancel();
        _boDemHienThi?.cancel();
      }
    } catch (loi) {
      if (mounted) {
        setState(() {
          _loiTaiPhong = loi.toString();
          _dangTaiDuLieu = false;
        });
      }
    } finally {
      _dangTaiPhong = false;
    }
  }

  Future<void> _guiCauTraLoi(int luaChon) async {
    final phong = _phongDau;
    if (phong == null ||
        phong.question == null ||
        phong.myAnswered ||
        _dangGuiCauTraLoi) {
      return;
    }
    setState(() {
      _dangGuiCauTraLoi = true;
      _luaChonDangGui = luaChon;
    });
    try {
      final phongMoi = await widget.service.submitAnswer(
        roomId: phong.id,
        questionIndex: phong.questionIndex,
        selectedIndex: luaChon,
      );
      if (mounted) setState(() => _phongDau = phongMoi);
    } catch (loi) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loi.toString())));
        await _taiPhong();
      }
    } finally {
      if (mounted) {
        setState(() {
          _dangGuiCauTraLoi = false;
          _luaChonDangGui = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phong = _phongDau;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trận đấu'),
        actions: [
          IconButton(
            tooltip: 'Tải lại trận đấu',
            onPressed: _dangTaiPhong ? null : _taiPhong,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _dangTaiDuLieu
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : phong == null
          ? _trangThaiTaiLoi()
          : _noiDungPhong(phong),
    );
  }

  Widget _trangThaiTaiLoi() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: AppColors.textSecondary,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              _loiTaiPhong ?? 'Không tải được trận đấu.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _taiPhong,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử tải lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noiDungPhong(PvpRoom phong) {
    if (phong.status == 'finished' || phong.status == 'cancelled') {
      return _ketQuaTran(phong);
    }
    if (phong.status == 'waiting') {
      return _choDoiThuChapNhan();
    }
    final cauHoi = phong.question;
    if (cauHoi == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final laChuPhong = widget.service.currentUserId == phong.hostId;
    final giayCon = _tinhGiayCon(phong);
    final mauDem = giayCon <= 5 ? AppColors.error : AppColors.primary;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _theDiem(
                ten: laChuPhong ? 'Bạn' : phong.hostName,
                diem: phong.hostScore,
                laBan: laChuPhong,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'VS',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _theDiem(
                ten: laChuPhong ? phong.guestName : 'Bạn',
                diem: phong.guestScore,
                laBan: !laChuPhong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${phong.questionIndex + 1} / ${phong.questionCount}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: mauDem, size: 20),
                      const SizedBox(width: 5),
                      Text(
                        '$giayCon giây',
                        style: TextStyle(
                          color: mauDem,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: phong.questionCount == 0
                      ? 0
                      : (phong.questionIndex + 1) / phong.questionCount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CÂU HỎI',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  cauHoi.content,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...cauHoi.options.asMap().entries.map((luaChon) {
          final dangChon = _luaChonDangGui == luaChon.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: phong.myAnswered || _dangGuiCauTraLoi
                    ? null
                    : () => _guiCauTraLoi(luaChon.key),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  backgroundColor: phong.myAnswered && dangChon
                      ? const Color(0xFFE0E7FF)
                      : Colors.white,
                  side: BorderSide(
                    color: phong.myAnswered && dangChon
                        ? AppColors.primaryLight
                        : const Color(0xFFCBD5E1),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        String.fromCharCode(65 + luaChon.key),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        luaChon.value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (dangChon && _dangGuiCauTraLoi)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (phong.myAnswered)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    phong.opponentAnswered
                        ? 'Cả hai đã trả lời. Đang chuyển câu...'
                        : 'Đã gửi đáp án. Đang chờ đối thủ...',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_loiTaiPhong != null) ...[
          const SizedBox(height: 8),
          Text(
            'Mất kết nối tạm thời. Đang thử lại: $_loiTaiPhong',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _choDoiThuChapNhan() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.primaryLight,
                  size: 46,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Đang chờ bạn chấp nhận lời mời',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Màn hình sẽ tự cập nhật khi trận đấu bắt đầu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _theDiem({
    required String ten,
    required int diem,
    required bool laBan,
  }) {
    return Card(
      elevation: 0,
      color: laBan ? const Color(0xFFEFF6FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: laBan ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Text(
              laBan ? 'BẠN' : 'ĐỐI THỦ',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              ten,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$diem điểm',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _tinhGiayCon(PvpRoom phong) {
    final batDauLuc = phong.questionStartTime;
    if (batDauLuc == null) return phong.questionSeconds;
    final soGiayDaQua = DateTime.now().toUtc().difference(batDauLuc).inSeconds;
    return (phong.questionSeconds - soGiayDaQua).clamp(
      0,
      phong.questionSeconds,
    );
  }

  Widget _ketQuaTran(PvpRoom phong) {
    final idNguoiChoi = widget.service.currentUserId;
    final hoa = phong.winnerId == null;
    final thang = phong.winnerId == idNguoiChoi;
    final tieuDe = phong.status == 'cancelled'
        ? 'Trận đấu đã bị hủy'
        : hoa
        ? 'Trận đấu hòa!'
        : thang
        ? 'Bạn đã chiến thắng!'
        : 'Đối thủ chiến thắng';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              phong.status == 'cancelled'
                  ? Icons.sports_kabaddi_outlined
                  : Icons.emoji_events_rounded,
              size: 68,
              color: phong.status == 'cancelled'
                  ? AppColors.textSecondary
                  : AppColors.accent,
            ),
            const SizedBox(height: 12),
            Text(
              tieuDe,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${phong.hostName}  ${phong.hostScore}  -  '
              '${phong.guestScore}  ${phong.guestName}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}
