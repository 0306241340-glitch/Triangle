import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/friend_model.dart';
import '../../services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.service, this.initialTab = 0});

  final FriendService? service;
  final int initialTab;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final FriendService _dichVuBanBe;
  late final TabController _boTab;
  final TextEditingController _oTimKiem = TextEditingController();
  final Map<String, Future<PublicProfile?>> _hoSoBan = {};

  late Future<void> _hoSoSanSang;
  late Future<List<FriendRequest>> _dsBanBe;
  late Future<List<FriendRequest>> _loiMoiDaNhan;
  late Future<List<FriendRequest>> _loiMoiDaGui;

  List<PublicProfile>? _ketQuaTimKiem;
  PublicProfile? _hoSoCuaToi;
  String? _loiKhoiTao;
  String? _loiTimKiem;
  String? _idDangXuLy;
  bool _dangTim = false;

  @override
  void initState() {
    super.initState();
    _dichVuBanBe = widget.service ?? FriendService();
    _boTab = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _hoSoSanSang = _chuanBiHoSo();
    _taiLaiQuanHe();
  }

  @override
  void dispose() {
    _boTab.dispose();
    _oTimKiem.dispose();
    super.dispose();
  }

  Future<void> _chuanBiHoSo() async {
    try {
      _hoSoCuaToi = await _dichVuBanBe.loadMyProfile();
      _loiKhoiTao = null;
    } catch (loi) {
      _loiKhoiTao = loi.toString();
    }
  }

  void _thuLaiKhoiTao() {
    setState(() {
      _loiKhoiTao = null;
      _hoSoSanSang = _chuanBiHoSo();
    });
  }

  void _taiLaiQuanHe() {
    setState(() {
      _hoSoBan.clear();
      _dsBanBe = _dichVuBanBe.loadFriends();
      _loiMoiDaNhan = _dichVuBanBe.loadRequests(laLoiMoiDen: true);
      _loiMoiDaGui = _dichVuBanBe.loadRequests(laLoiMoiDen: false);
    });
  }

  Future<void> _timBan() async {
    final tuKhoa = _oTimKiem.text.trim();
    if (tuKhoa.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập ít nhất 2 ký tự để tìm bạn.')),
      );
      return;
    }

    setState(() {
      _dangTim = true;
      _loiTimKiem = null;
      _ketQuaTimKiem = null;
    });

    try {
      final ketQua = await _dichVuBanBe.searchUsers(tuKhoa);
      if (!mounted) return;
      setState(() => _ketQuaTimKiem = ketQua);
    } catch (loi) {
      if (!mounted) return;
      setState(() => _loiTimKiem = loi.toString());
    } finally {
      if (mounted) setState(() => _dangTim = false);
    }
  }

  Future<void> _saoChepMaBanBe() async {
    final maBanBe = _hoSoCuaToi?.userCode ?? '';
    if (maBanBe.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: maBanBe));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã sao chép mã kết bạn.')));
  }

  Future<void> _thucHienTacVu(
    String id,
    Future<void> Function() tacVu, {
    required String thongBao,
  }) async {
    if (_idDangXuLy != null) return;
    setState(() => _idDangXuLy = id);
    try {
      await tacVu();
      if (!mounted) return;
      _taiLaiQuanHe();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(thongBao)));
    } catch (loi) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loi.toString())));
    } finally {
      if (mounted) setState(() => _idDangXuLy = null);
    }
  }

  Future<PublicProfile?> _taiHoSoBan(String idNguoiDung) {
    return _hoSoBan.putIfAbsent(
      idNguoiDung,
      () => _dichVuBanBe.getPublicProfile(idNguoiDung),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bạn bè'),
        bottom: TabBar(
          controller: _boTab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primaryLight,
          indicatorWeight: 3,
          labelStyle: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
          tabs: [
            const Tab(text: 'Bạn bè'),
            Tab(child: _tabLoiMoiCoSo()),
            const Tab(text: 'Tìm bạn'),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _hoSoSanSang,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (_loiKhoiTao != null) return _loiTaoHoSo();
          return TabBarView(
            controller: _boTab,
            children: [_tabBanBe(), _tabLoiMoi(), _tabTimBan()],
          );
        },
      ),
    );
  }

  Widget _loiTaoHoSo() {
    return _trangThaiLoi(noiDung: _loiKhoiTao!, thuLai: _thuLaiKhoiTao);
  }

  Widget _tabBanBe() {
    return FutureBuilder<List<FriendRequest>>(
      future: _dsBanBe,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _trangThaiLoi(
            noiDung: 'Không tải được danh sách bạn bè.',
            thuLai: _taiLaiQuanHe,
          );
        }
        if (!snapshot.hasData) return _dangTai();
        final banBe = snapshot.data!;
        if (banBe.isEmpty) {
          return _trangThaiBanBeTrong();
        }

        return RefreshIndicator(
          onRefresh: () async => _taiLaiQuanHe(),
          color: AppColors.primary,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: banBe.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final quanHe = banBe[index];
              final idNguoiDung = quanHe.otherUserId(
                _dichVuBanBe.currentUserId,
              );
              return _theHoSo(
                idNguoiDung,
                tacVu: TextButton.icon(
                  onPressed: _idDangXuLy == null
                      ? () => _thucHienTacVu(
                          quanHe.id,
                          () => _dichVuBanBe.removeFriend(quanHe.id),
                          thongBao: 'Đã xóa bạn bè.',
                        )
                      : null,
                  icon: _idDangXuLy == quanHe.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('Xóa'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _tabLoiMoi() {
    return RefreshIndicator(
      onRefresh: () async => _taiLaiQuanHe(),
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _tieuDeNhom('Lời mời đã nhận'),
          const SizedBox(height: 8),
          _dsLoiMoi(future: _loiMoiDaNhan, laLoiMoiDen: true),
          const SizedBox(height: 22),
          _tieuDeNhom('Lời mời đã gửi'),
          const SizedBox(height: 8),
          _dsLoiMoi(future: _loiMoiDaGui, laLoiMoiDen: false),
        ],
      ),
    );
  }

  Widget _tabLoiMoiCoSo() {
    return FutureBuilder<List<FriendRequest>>(
      future: _loiMoiDaNhan,
      builder: (context, snapshot) {
        final soLoiMoi = snapshot.data?.length ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lời mời'),
            if (soLoiMoi > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$soLoiMoi',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _dsLoiMoi({
    required Future<List<FriendRequest>> future,
    required bool laLoiMoiDen,
  }) {
    return FutureBuilder<List<FriendRequest>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _khungThongBao(
            icon: Icons.cloud_off_outlined,
            noiDung: 'Không tải được lời mời kết bạn.',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        final loiMoi = snapshot.data!;
        if (loiMoi.isEmpty) {
          return _khungThongBao(
            icon: Icons.mark_email_read_outlined,
            noiDung: laLoiMoiDen
                ? 'Chưa có lời mời mới.'
                : 'Bạn chưa gửi lời mời nào.',
          );
        }

        return Column(
          children: loiMoi.map((quanHe) {
            final idNguoiDung = quanHe.otherUserId(_dichVuBanBe.currentUserId);
            final dangXuLy = _idDangXuLy == quanHe.id;
            final Widget nut;
            if (laLoiMoiDen) {
              nut = Wrap(
                spacing: 4,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Chấp nhận',
                    onPressed: _idDangXuLy == null
                        ? () => _thucHienTacVu(
                            quanHe.id,
                            () => _dichVuBanBe.acceptRequest(quanHe.id),
                            thongBao: 'Đã chấp nhận lời mời.',
                          )
                        : null,
                    icon: dangXuLy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                  ),
                  IconButton(
                    tooltip: 'Từ chối',
                    onPressed: _idDangXuLy == null
                        ? () => _thucHienTacVu(
                            quanHe.id,
                            () => _dichVuBanBe.rejectRequest(quanHe.id),
                            thongBao: 'Đã từ chối lời mời.',
                          )
                        : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              );
            } else {
              nut = TextButton(
                onPressed: _idDangXuLy == null
                    ? () => _thucHienTacVu(
                        quanHe.id,
                        () => _dichVuBanBe.cancelRequest(quanHe.id),
                        thongBao: 'Đã thu hồi lời mời.',
                      )
                    : null,
                child: dangXuLy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Thu hồi'),
              );
            }
            return _theHoSo(idNguoiDung, tacVu: nut);
          }).toList(),
        );
      },
    );
  }

  Widget _tabTimBan() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _theMaBanBeCuaToi(),
        const SizedBox(height: 16),
        TextField(
          controller: _oTimKiem,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _timBan(),
          decoration: InputDecoration(
            hintText: 'Nhập tên hoặc mã bạn bè',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: 'Tìm kiếm',
              onPressed: _dangTim ? null : _timBan,
              icon: _dangTim
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loiTimKiem != null)
          _khungThongBao(
            icon: Icons.cloud_off_outlined,
            noiDung: 'Tìm kiếm thất bại: $_loiTimKiem',
          )
        else if (_dangTim)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_ketQuaTimKiem == null)
          _khungThongBao(
            icon: Icons.person_search_outlined,
            noiDung: 'Nhập ít nhất 2 ký tự để tìm người chơi.',
          )
        else if (_ketQuaTimKiem!.isEmpty)
          _khungThongBao(
            icon: Icons.search_off_rounded,
            noiDung: 'Không tìm thấy người chơi phù hợp.',
          )
        else
          ..._ketQuaTimKiem!.map(_theKetQuaTimKiem),
      ],
    );
  }

  Widget _theMaBanBeCuaToi() {
    final maBanBe = _hoSoCuaToi?.userCode ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mã kết bạn của bạn', style: AppTheme.caption),
                const SizedBox(height: 3),
                Text(
                  maBanBe,
                  style: AppTheme.cardTitle.copyWith(letterSpacing: 1),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _saoChepMaBanBe,
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }

  Widget _trangThaiBanBeTrong() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: () async => _taiLaiQuanHe(),
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.group_add_outlined,
                          size: 38,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có bạn bè',
                        style: AppTheme.sectionTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tìm người chơi theo tên hoặc mã để cùng tham gia.',
                        textAlign: TextAlign.center,
                        style: AppTheme.body.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () => _boTab.animateTo(2),
                        icon: const Icon(Icons.person_search_rounded),
                        label: const Text('Tìm bạn bè'),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _saoChepMaBanBe,
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Chia sẻ mã của tôi'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _theKetQuaTimKiem(PublicProfile hoSo) {
    final dangXuLy = _idDangXuLy == hoSo.uid;
    return _theHoSo(
      hoSo.uid,
      hoSoCoSan: hoSo,
      tacVu: FilledButton.tonalIcon(
        onPressed: _idDangXuLy == null
            ? () => _thucHienTacVu(
                hoSo.uid,
                () => _dichVuBanBe.sendRequest(hoSo.uid),
                thongBao: 'Đã gửi lời mời kết bạn.',
              )
            : null,
        icon: dangXuLy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Kết bạn'),
      ),
    );
  }

  Widget _theHoSo(
    String idNguoiDung, {
    required Widget tacVu,
    PublicProfile? hoSoCoSan,
  }) {
    if (hoSoCoSan != null) return _taoTheHoSo(hoSoCoSan, tacVu);
    return FutureBuilder<PublicProfile?>(
      future: _taiHoSoBan(idNguoiDung),
      builder: (context, snapshot) {
        final hoSo = snapshot.data;
        if (snapshot.hasError) {
          return _khungThongBao(
            icon: Icons.person_off_outlined,
            noiDung: 'Không tải được hồ sơ người chơi.',
          );
        }
        if (hoSo == null) {
          return Card(
            elevation: 0,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Icon(Icons.person_outline, color: AppColors.primary),
              ),
              title: Text(
                snapshot.connectionState == ConnectionState.waiting
                    ? 'Đang tải hồ sơ...'
                    : 'Không tìm thấy người chơi.',
              ),
            ),
          );
        }
        return _taoTheHoSo(hoSo, tacVu);
      },
    );
  }

  Widget _taoTheHoSo(PublicProfile hoSo, Widget tacVu) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _anhDaiDien(hoSo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hoSo.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.cardTitle,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hoSo.userCode.isEmpty
                        ? 'Người chơi'
                        : 'Mã: ${hoSo.userCode}',
                    style: AppTheme.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            tacVu,
          ],
        ),
      ),
    );
  }

  Widget _anhDaiDien(PublicProfile hoSo) {
    final duongDanAnh = hoSo.avatarUrl;
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primarySurface,
      foregroundImage: duongDanAnh.startsWith('http')
          ? NetworkImage(duongDanAnh)
          : null,
      child: duongDanAnh.startsWith('http')
          ? null
          : Text(
              _layChuCaiDau(hoSo.displayName),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _tieuDeNhom(String ten) {
    return Text(ten, style: AppTheme.sectionTitle);
  }

  Widget _khungThongBao({required IconData icon, required String noiDung}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              noiDung,
              style: AppTheme.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trangThaiLoi({
    required String noiDung,
    required VoidCallback thuLai,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 42,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(noiDung, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: thuLai,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangTai() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  String _layChuCaiDau(String ten) {
    final cacTu = ten.trim().split(RegExp(r'\s+'));
    if (cacTu.isEmpty || cacTu.first.isEmpty) return '?';
    if (cacTu.length == 1) return cacTu.first.characters.first.toUpperCase();
    return '${cacTu.first.characters.first}${cacTu.last.characters.first}'
        .toUpperCase();
  }
}
