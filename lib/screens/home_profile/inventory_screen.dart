import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/item_model.dart';
import '../../services/store_service.dart';
import '../../widgets/item_visual.dart';
import 'store_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key, this.service});

  final StoreService? service;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final StoreService _dichVuCuaHang;
  List<_VatPhamSoHuu> _vatPham = [];
  String _loaiDangChon = 'all';
  bool _dangTai = false;
  String? _loi;
  String? _idDangTrangBi;

  static const _cacLoaiVatPham = {
    'all': 'Tất cả',
    'help': 'Trợ giúp',
    'frame': 'Khung',
    'title': 'Danh hiệu',
  };

  @override
  void initState() {
    super.initState();
    _dichVuCuaHang = widget.service ?? StoreService();
    _taiTuiDo();
  }

  Future<void> _taiTuiDo() async {
    if (_dangTai) return;
    setState(() {
      _dangTai = true;
      _loi = null;
    });

    try {
      final duLieu = await _dichVuCuaHang.loadInventory();
      final danhSachVatPham = duLieu['items'];
      final danhSachSoHuu = duLieu['userItems'];
      if (danhSachVatPham is! List || danhSachSoHuu is! List) {
        throw const FormatException('Dữ liệu túi đồ không đúng định dạng.');
      }

      final vatPhamTheoId = <String, StoreItem>{};
      for (final duLieuVatPham in danhSachVatPham) {
        if (duLieuVatPham is Map<String, dynamic>) {
          final vatPham = StoreItem.fromJson(duLieuVatPham);
          vatPhamTheoId[vatPham.id] = vatPham;
        }
      }

      final vatPhamSoHuu = <_VatPhamSoHuu>[];
      for (final duLieuSoHuu in danhSachSoHuu) {
        if (duLieuSoHuu is! Map<String, dynamic>) continue;
        final idVatPham = duLieuSoHuu['itemId']?.toString();
        final vatPham = idVatPham == null ? null : vatPhamTheoId[idVatPham];
        if (vatPham == null) continue;

        vatPhamSoHuu.add(
          _VatPhamSoHuu(
            vatPham: vatPham,
            soLuong: (duLieuSoHuu['quantity'] as num?)?.toInt() ?? 0,
            dangTrangBi: duLieuSoHuu['equipped'] == true,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _vatPham = vatPhamSoHuu;
        _loi = null;
      });
    } catch (loi) {
      if (!mounted) return;
      setState(() => _loi = loi.toString());
    } finally {
      if (mounted) setState(() => _dangTai = false);
    }
  }

  Future<void> _doiTrangThaiTrangBi(_VatPhamSoHuu vatPham) async {
    if (_idDangTrangBi != null) return;
    setState(() => _idDangTrangBi = vatPham.vatPham.id);

    try {
      await _dichVuCuaHang.setEquipped(
        vatPham.vatPham.id,
        equipped: !vatPham.dangTrangBi,
      );
      if (!mounted) return;
      await _taiTuiDo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vatPham.dangTrangBi
                ? 'Đã tháo ${vatPham.vatPham.name}.'
                : 'Đã trang bị ${vatPham.vatPham.name}.',
          ),
        ),
      );
    } catch (loi) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể thay đổi trang bị: $loi')),
      );
    } finally {
      if (mounted) setState(() => _idDangTrangBi = null);
    }
  }

  void _denCuaHang() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
    ).then((_) {
      if (mounted) _taiTuiDo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vatPhamHienThi = _vatPham
        .where((vatPham) => _dungLoai(vatPham, _loaiDangChon))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Túi đồ')),
      body: RefreshIndicator(
        onRefresh: _taiTuiDo,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _theTongQuan(),
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _cacLoaiVatPham.entries.map((loai) {
                  final soLuong = _demVatPham(loai.key);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${loai.value} $soLuong'),
                      selected: _loaiDangChon == loai.key,
                      onSelected: (_) =>
                          setState(() => _loaiDangChon = loai.key),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            if (_dangTai && _vatPham.isEmpty)
              _trangThaiDangTai()
            else if (_loi != null && _vatPham.isEmpty)
              _trangThaiLoi()
            else if (vatPhamHienThi.isEmpty)
              _trangThaiTrong()
            else
              ...vatPhamHienThi.map(_theVatPham),
            if (_loi != null && _vatPham.isNotEmpty) ...[
              const SizedBox(height: 4),
              _theLoi(),
            ],
          ],
        ),
      ),
    );
  }

  int _demVatPham(String loai) {
    return _vatPham.where((vatPham) => _dungLoai(vatPham, loai)).length;
  }

  bool _dungLoai(_VatPhamSoHuu vatPham, String loai) {
    return loai == 'all' ||
        vatPham.vatPham.type == loai ||
        (loai == 'help' && vatPham.vatPham.type == 'lifeline');
  }

  Widget _theTongQuan() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bộ sưu tập của bạn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_vatPham.length} vật phẩm đang sở hữu',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _theVatPham(_VatPhamSoHuu vatPham) {
    final laKhung = vatPham.vatPham.type == 'frame';
    final laDoTrangBi = laKhung || vatPham.vatPham.type == 'title';
    final dangXuLy = _idDangTrangBi == vatPham.vatPham.id;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ItemVisual(
              imageUrl: vatPham.vatPham.imageUrl,
              type: vatPham.vatPham.type,
              code: vatPham.vatPham.effect,
              itemId: vatPham.vatPham.id,
              name: vatPham.vatPham.name,
              size: laKhung ? 58 : 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vatPham.vatPham.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (vatPham.vatPham.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      vatPham.vatPham.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (vatPham.dangTrangBi)
                    _nhanDangSuDung()
                  else
                    Text(
                      'Số lượng: ${vatPham.soLuong}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (laDoTrangBi) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _idDangTrangBi == null
                    ? () => _doiTrangThaiTrangBi(vatPham)
                    : null,
                child: dangXuLy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(vatPham.dangTrangBi ? 'Tháo' : 'Trang bị'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nhanDangSuDung() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F7EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
          SizedBox(width: 4),
          Text(
            'Đang sử dụng',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trangThaiDangTai() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }

  Widget _trangThaiTrong() {
    final laTuiDoTrong = _vatPham.isEmpty;
    final tenLoai = _cacLoaiVatPham[_loaiDangChon]?.toLowerCase() ?? 'vật phẩm';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.primaryLight,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              laTuiDoTrong ? 'Túi đồ đang trống' : 'Chưa có $tenLoai nào',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: _denCuaHang, child: const Text('Cửa hàng')),
        ],
      ),
    );
  }

  Widget _trangThaiLoi() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            _loi!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          TextButton.icon(
            onPressed: _dangTai ? null : _taiTuiDo,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _theLoi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(
        'Làm mới túi đồ không thành công: $_loi',
        style: const TextStyle(color: Color(0xFF7C2D12)),
      ),
    );
  }
}

class _VatPhamSoHuu {
  const _VatPhamSoHuu({
    required this.vatPham,
    required this.soLuong,
    required this.dangTrangBi,
  });

  final StoreItem vatPham;
  final int soLuong;
  final bool dangTrangBi;
}
