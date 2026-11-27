import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/friend_model.dart';
import '../../models/notification_model.dart';
import '../../models/room_model.dart';
import '../../viewmodels/pvp_social_vm.dart';
import '../home_profile/friends_screen.dart';

class PvpSocialScreen extends StatefulWidget {
  const PvpSocialScreen({super.key, this.vm});

  final PvpSocialViewModel? vm;

  @override
  State<PvpSocialScreen> createState() => _PvpSocialScreenState();
}

class _PvpSocialScreenState extends State<PvpSocialScreen>
    with SingleTickerProviderStateMixin {
  static const _mauNen = AppColors.background;
  static const _mauThe = AppColors.surface;
  static const _mauVien = AppColors.border;
  static const _mauNenBieuTuong = AppColors.primarySurface;
  static const _mauXanh = AppColors.primary;
  static const _mauChuPhu = AppColors.textSecondary;

  late final PvpSocialViewModel _boDieuKhien;
  bool _tuTaoViewModel = false;
  late final TabController _boChuyenTab;

  @override
  void initState() {
    super.initState();
    _tuTaoViewModel = widget.vm == null;
    _boDieuKhien = widget.vm ?? PvpSocialViewModel();
    _boDieuKhien.init();
    _boChuyenTab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _boChuyenTab.dispose();
    if (_tuTaoViewModel) _boDieuKhien.dispose();
    super.dispose();
  }

  void _taiLaiBanBe() {
    _boDieuKhien.reloadFriends();
  }

  void _taiLaiLoiMoi() {
    if (mounted) _boDieuKhien.reloadInvitations();
  }

  Future<PublicProfile?> _taiHoSoBan(String idNguoiDung) {
    return _boDieuKhien.getProfile(idNguoiDung);
  }

  Future<void> _timTranNgauNhien() async {
    final ketQua = await _boDieuKhien.startQueue();
    if (!mounted) return;
    if (ketQua.maPhong != null) {
      await _moPhong(ketQua.maPhong!);
    } else if (ketQua.thongBao != null) {
      _hienThongBao(ketQua.thongBao!);
    }
  }

  Future<void> _huyTimTran() async {
    final ketQua = await _boDieuKhien.cancelQueue();
    if (!mounted) return;
    if (ketQua.maPhong != null) {
      await _moPhong(ketQua.maPhong!);
    } else if (ketQua.thongBao != null) {
      _hienThongBao(ketQua.thongBao!);
    }
  }

  Future<void> _thachDauBan(String idBan) async {
    final ketQua = await _boDieuKhien.inviteFriend(idBan);
    if (!mounted) return;
    if (ketQua.maPhong != null) {
      await _moPhong(ketQua.maPhong!);
    } else if (ketQua.thongBao != null) {
      _hienThongBao(ketQua.thongBao!);
    }
  }

  Future<void> _phanHoiLoiMoi(
    PvpInvitation loiMoi, {
    required bool chapNhan,
  }) async {
    final ketQua = await _boDieuKhien.respondToInvitation(
      loiMoi,
      chapNhan: chapNhan,
    );
    if (!mounted) return;
    if (ketQua.maPhong != null) {
      await _moPhong(ketQua.maPhong!);
    } else if (ketQua.thongBao != null) {
      _hienThongBao(ketQua.thongBao!);
    }
  }

  Future<void> _moPhong(String maPhong) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PvpRoomScreen(
          roomVm: PvpRoomViewModel(
            roomId: maPhong,
            service: _boDieuKhien.dichVuPvp,
          ),
        ),
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
    final ketQua = await _boDieuKhien.copyMyFriendCode();
    if (!mounted) return;
    if (ketQua.thongBao == null) return;
    final maBanBe = ketQua.thongBao!;
    if (maBanBe == 'Chưa có mã kết bạn.' ||
        maBanBe == 'Không thể chia sẻ mã kết bạn.') {
      _hienThongBao(maBanBe);
      return;
    }
    await Clipboard.setData(ClipboardData(text: maBanBe));
    if (mounted) _hienThongBao('Đã sao chép mã kết bạn.');
  }

  void _moTabThachBan() {
    _boChuyenTab.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _boDieuKhien,
      builder: (context, _) => Scaffold(
        backgroundColor: _mauNen,
        appBar: AppBar(
          backgroundColor: _mauNen,
          foregroundColor: _mauXanh,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: const Text('Đấu 1 vs 1'),
          bottom: TabBar(
            controller: _boChuyenTab,
            labelColor: _mauXanh,
            unselectedLabelColor: _mauChuPhu,
            labelStyle: AppTheme.body.copyWith(fontWeight: FontWeight.w700),
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
      ),
    );
  }

  Widget _tabDauNhanh() {
    return ColoredBox(
      color: _mauNen,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                Text(
                  'Sẵn sàng so tài?',
                  style: AppTheme.pageTitle.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tìm người chơi có điểm số phù hợp với bạn.',
                  style: AppTheme.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
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
                    onPressed: _boDieuKhien.dangTimTran
                        ? _huyTimTran
                        : _timTranNgauNhien,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: _boDieuKhien.dangTimTran
                        ? const Icon(Icons.close_rounded)
                        : const Icon(Icons.search_rounded),
                    label: Text(
                      _boDieuKhien.dangTimTran
                          ? 'Hủy tìm trận'
                          : 'Tìm trận ngay',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_boDieuKhien.dangTimTran) ...[
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
                    style: AppTheme.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Luật chơi', style: AppTheme.sectionTitle),
          ),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              side: const BorderSide(color: AppColors.border),
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
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: AppTheme.body.copyWith(
                              color: _mauChuPhu,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(
                                text: 'Mỗi câu chỉ trả lời một lần. ',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
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
                  const Divider(height: 24, color: AppColors.border),
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
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: AppTheme.body.copyWith(
                              color: _mauChuPhu,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(
                                text: 'Hết 15 giây ',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
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
      future: _boDieuKhien.dsBanBe,
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
              final idNguoiDung = quanHe.otherUserId(_boDieuKhien.maNguoiDung);
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
        final dangGui = _boDieuKhien.idDangXuLy == idNguoiDung;
        return Card(
          color: _mauThe,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                        style: AppTheme.cardTitle,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        snapshot.hasError
                            ? 'Chưa tải được thông tin'
                            : hoSo?.userCode.isNotEmpty == true
                            ? 'Mã bạn bè: ${hoSo!.userCode}'
                            : 'Sẵn sàng thách đấu',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _boDieuKhien.idDangXuLy == null
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
    return StreamBuilder<List<PvpInvitation>>(
      stream: _boDieuKhien.luongLoiMoi,
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
          if (_boDieuKhien.loiDongBoLoiMoi != null) {
            return _trangThaiLoi(
              'Không thể đồng bộ lời mời thách đấu: '
              '${_boDieuKhien.loiDongBoLoiMoi}',
              _taiLaiLoiMoi,
            );
          }
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
    final dangXuLy = _boDieuKhien.idDangXuLy == loiMoi.roomId;
    return Card(
      color: _mauThe,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                        style: AppTheme.cardTitle,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Mời bạn đấu 10 câu hỏi',
                        style: AppTheme.caption,
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
                    onPressed: _boDieuKhien.idDangXuLy == null
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
                    style: AppTheme.sectionTitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    moTa,
                    textAlign: TextAlign.center,
                    style: AppTheme.body.copyWith(
                      color: _mauChuPhu,
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
            Text(noiDung, textAlign: TextAlign.center, style: AppTheme.body),
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
            style: AppTheme.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PvpRoomScreen extends StatefulWidget {
  const PvpRoomScreen({required this.roomVm, super.key});

  final PvpRoomViewModel roomVm;

  @override
  State<PvpRoomScreen> createState() => _PvpRoomScreenState();
}

class _PvpRoomScreenState extends State<PvpRoomScreen> {
  PvpRoomViewModel get _boDieuKhien => widget.roomVm;
  bool _tuTaoViewModel = false;

  @override
  void initState() {
    super.initState();
    _tuTaoViewModel = true;
    _boDieuKhien.init();
  }

  @override
  void dispose() {
    if (_tuTaoViewModel) _boDieuKhien.dispose();
    super.dispose();
  }

  Future<void> _taiPhong() async {
    await _boDieuKhien.loadRoom();
  }

  Future<void> _guiCauTraLoi(int luaChon) async {
    final loi = await _boDieuKhien.submitAnswer(luaChon);
    if (mounted && loi != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  Future<void> _huyLoiMoi() async {
    final loi = await _boDieuKhien.cancelInvitation();
    if (mounted && loi != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _boDieuKhien,
      builder: (context, _) {
        final phong = _boDieuKhien.phong;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Trận đấu')),
          body: _boDieuKhien.dangTai
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : phong == null
              ? _trangThaiTaiLoi()
              : _noiDungPhong(phong),
        );
      },
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
              _boDieuKhien.loi ?? 'Không tải được trận đấu.',
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
      return _choDoiThuChapNhan(phong);
    }
    final cauHoi = phong.question;
    if (cauHoi == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final laChuPhong = _boDieuKhien.maNguoiDung == phong.hostId;
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
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: AppColors.border),
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
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CÂU HỎI',
                  style: AppTheme.caption.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  cauHoi.content,
                  style: AppTheme.sectionTitle.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...cauHoi.options.asMap().entries.map((luaChon) {
          final dangChon = _boDieuKhien.luaChonDaChon == luaChon.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: phong.myAnswered || _boDieuKhien.dangGuiDapAn
                    ? null
                    : () => _guiCauTraLoi(luaChon.key),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  backgroundColor: phong.myAnswered && dangChon
                      ? AppColors.primarySurface
                      : Colors.white,
                  side: BorderSide(
                    color: phong.myAnswered && dangChon
                        ? AppColors.primaryLight
                        : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.primarySurface,
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
                    Expanded(child: Text(luaChon.value, style: AppTheme.body)),
                    if (dangChon && _boDieuKhien.dangGuiDapAn)
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
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
        if (_boDieuKhien.loi != null) ...[
          const SizedBox(height: 8),
          Text(
            'Mất kết nối tạm thời. Đang thử lại: ${_boDieuKhien.loi}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _choDoiThuChapNhan(PvpRoom phong) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            side: const BorderSide(color: AppColors.border),
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
                  'Đang chờ bạn bè chấp nhận lời mời',
                  textAlign: TextAlign.center,
                  style: AppTheme.sectionTitle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Màn hình sẽ tự cập nhật khi trận đấu bắt đầu.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                if (_boDieuKhien.maNguoiDung == phong.hostId) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _boDieuKhien.dangHuy ? null : _huyLoiMoi,
                    icon: _boDieuKhien.dangHuy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close),
                    label: Text(
                      _boDieuKhien.dangHuy
                          ? 'Đang hủy lời mời...'
                          : 'Hủy lời mời',
                    ),
                  ),
                ],
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
      color: laBan ? AppColors.primarySurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: laBan ? AppColors.primaryLight : AppColors.border,
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
              style: AppTheme.cardTitle,
            ),
            Text(
              '$diem điểm',
              style: AppTheme.sectionTitle.copyWith(color: AppColors.primary),
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
    final idNguoiChoi = _boDieuKhien.maNguoiDung;
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
              style: AppTheme.pageTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${phong.hostName}  ${phong.hostScore}  -  '
              '${phong.guestScore}  ${phong.guestName}',
              textAlign: TextAlign.center,
              style: AppTheme.cardTitle.copyWith(
                color: AppColors.textSecondary,
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
