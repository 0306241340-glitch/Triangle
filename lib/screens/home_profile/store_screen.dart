import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/item_model.dart';
import '../../services/store_service.dart';
import '../../viewmodels/home_profile_vm.dart';
import '../../widgets/item_visual.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.service, this.homeVm});

  final StoreService? service;
  final HomeViewModel? homeVm;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late final StoreService _dichVuCuaHang;
  late final HomeViewModel _duLieuTrangChu;
  StoreCatalog _danhMuc = const StoreCatalog(
    coins: null,
    items: [],
    ownedQuantities: {},
  );
  String _loaiDangChon = 'all';
  String? _loi;
  String? _idDangMua;
  bool _mayChuSanSang = false;
  bool _dangTai = false;

  static const _cacLoaiVatPham = {
    'all': 'Tất cả',
    'help': 'Trợ giúp',
    'frame': 'Khung avatar',
    'title': 'Danh hiệu',
  };

  @override
  void initState() {
    super.initState();
    _dichVuCuaHang = widget.service ?? StoreService();
    _duLieuTrangChu = widget.homeVm ?? HomeViewModel();
    _taiDanhSachVatPham();
  }

  @override
  void dispose() {
    if (widget.homeVm == null) {
      _duLieuTrangChu.dispose();
    }
    super.dispose();
  }

  Future<void> _taiDanhSachVatPham() async {
    if (_dangTai) return;
    setState(() {
      _dangTai = true;
      _loi = null;
    });

    try {
      final danhMuc = await _dichVuCuaHang.loadCatalog();
      if (!mounted) return;
      _duLieuTrangChu.syncCatalog(danhMuc);
      setState(() {
        _danhMuc = danhMuc;
        _loi = null;
        _mayChuSanSang = true;
        _dangTai = false;
      });
    } catch (loi) {
      if (!mounted) return;
      setState(() {
        _loi = 'Không thể tải cửa hàng: $loi';
        _mayChuSanSang = false;
        _dangTai = false;
      });
    }
  }

  Future<void> _xacNhanMuaVatPham(StoreItem vatPham) async {
    if (_idDangMua != null || !_mayChuSanSang) return;
    final daXacNhan = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận mua'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn muốn mua ${vatPham.name}?'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.monetization_on_outlined,
                  color: AppColors.accentDark,
                ),
                const SizedBox(width: 8),
                Text(
                  '${vatPham.price} xu',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận mua'),
          ),
        ],
      ),
    );
    if (daXacNhan != true || !mounted || _idDangMua != null) return;

    setState(() => _idDangMua = vatPham.id);
    try {
      final ketQua = await _dichVuCuaHang.purchase(vatPham.id);
      if (!mounted) return;

      _duLieuTrangChu.updateAfterPurchase(
        vatPham,
        ketQua.coins,
        ketQua.quantity,
      );
      setState(() {
        _danhMuc = _danhMuc.copyWith(
          coins: _duLieuTrangChu.coins,
          ownedQuantities: Map<String, int>.from(_duLieuTrangChu.ownedItems),
        );
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đã mua ${vatPham.name}.')));
    } catch (loi) {
      if (!mounted) return;
      final mayChuLoi =
          loi is SocketException ||
          loi is HttpException ||
          loi is ApiException &&
              (loi.statusCode == 404 || loi.statusCode >= 500);
      if (mayChuLoi) {
        setState(() {
          _mayChuSanSang = false;
          _loi = 'Máy chủ cửa hàng hiện chưa khả dụng. Giao dịch chưa được ghi nhận.';
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mayChuLoi
                ? 'Máy chủ cửa hàng chưa khả dụng. Chưa thực hiện giao dịch.'
                : 'Không thể mua ${vatPham.name}: $loi',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _idDangMua = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cửa hàng')),
      body: _danhSachVatPham(_danhMuc),
    );
  }

  Widget _danhSachVatPham(StoreCatalog danhMuc) {
    final danhSachVatPham = danhMuc.items
        .where(
          (vatPham) =>
              _loaiDangChon == 'all' ||
              vatPham.type == _loaiDangChon ||
              (_loaiDangChon == 'help' && vatPham.type == 'lifeline'),
        )
        .toList();

    return RefreshIndicator(
      onRefresh: _taiDanhSachVatPham,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_loi != null) _thongBaoMayChu(),
          _theSoDu(danhMuc.coins),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text('Vật phẩm', style: AppTheme.sectionTitle),
              ),
              Text('${danhSachVatPham.length} món', style: AppTheme.caption),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _cacLoaiVatPham.entries.map((luaChon) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(luaChon.value),
                    selected: _loaiDangChon == luaChon.key,
                    onSelected: (_) =>
                        setState(() => _loaiDangChon = luaChon.key),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          if (_dangTai && danhMuc.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 52),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text('Đang tải vật phẩm...', style: AppTheme.caption),
                  ],
                ),
              ),
            )
          else if (danhSachVatPham.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 38,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Chưa có vật phẩm trong danh mục này.',
                      textAlign: TextAlign.center,
                      style: AppTheme.caption,
                    ),
                  ],
                ),
              ),
            )
          else
            ...danhSachVatPham.map((vatPham) => _theVatPham(vatPham, danhMuc)),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _thongBaoMayChu() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF9A3412)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _loi!,
              style: const TextStyle(color: Color(0xFF7C2D12)),
            ),
          ),
          IconButton(
            tooltip: 'Kết nối lại',
            onPressed: _dangTai ? null : _taiDanhSachVatPham,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _theSoDu(int? soXu) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Số xu của bạn',
              style: AppTheme.cardTitle.copyWith(color: Colors.white),
            ),
          ),
          Text(
            soXu == null ? '—' : '$soXu xu',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _theVatPham(StoreItem vatPham, StoreCatalog danhMuc) {
    final soLuong = danhMuc.ownedQuantities[vatPham.id] ?? 0;
    final daSoHuu = soLuong > 0 && !vatPham.isStackable;
    final dangMua = _idDangMua == vatPham.id;
    final dangCoGiaoDich = _idDangMua != null;
    final soXuHienCo = danhMuc.coins ?? 0;
    final soXuThieu = vatPham.price - soXuHienCo;
    final thieuXu = danhMuc.coins != null && soXuThieu > 0;
    final double tienDoXu = vatPham.price <= 0
        ? 1
        : (soXuHienCo / vatPham.price).clamp(0.0, 1.0).toDouble();
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ItemVisual(
                  imageUrl: vatPham.imageUrl,
                  type: vatPham.type,
                  code: vatPham.effect,
                  itemId: vatPham.id,
                  name: vatPham.name,
                  size: vatPham.type == 'frame' ? 58 : 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vatPham.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.cardTitle,
                      ),
                      if (vatPham.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          vatPham.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.caption.copyWith(height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (daSoHuu)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Đã sở hữu',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else if (thieuXu)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _giaVatPham(vatPham.price),
                      const Spacer(),
                      FilledButton(
                        onPressed: null,
                        child: Text('Còn thiếu $soXuThieu xu'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: tienDoXu,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: AppColors.primaryLight,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Đã có $soXuHienCo/${vatPham.price} xu',
                    style: AppTheme.caption,
                  ),
                ],
              )
            else
              Row(
                children: [
                  _giaVatPham(vatPham.price),
                  if (soLuong > 0) ...[
                    const SizedBox(width: 10),
                    Text('Đang có: $soLuong', style: AppTheme.caption),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: dangCoGiaoDich || !_mayChuSanSang
                        ? null
                        : () => _xacNhanMuaVatPham(vatPham),
                    child: dangMua
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Mua · ${vatPham.price} xu'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _giaVatPham(int gia) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.monetization_on_rounded,
          color: AppColors.accentDark,
          size: 18,
        ),
        const SizedBox(width: 4),
        Text(
          '$gia xu',
          style: const TextStyle(
            color: AppColors.accentDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
