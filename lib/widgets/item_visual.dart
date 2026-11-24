import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/frame_assets.dart';

class ItemVisual extends StatefulWidget {
  const ItemVisual({
    super.key,
    required this.imageUrl,
    required this.type,
    this.code = '',
    this.itemId = '',
    this.name = '',
    this.size = 48,
  });

  final String imageUrl;
  final String type;
  final String code;
  final String itemId;
  final String name;
  final double size;

  @override
  State<ItemVisual> createState() => _ItemVisualState();
}

class _ItemVisualState extends State<ItemVisual> {
  Uint8List? _duLieuAnh;
  bool _anhKhongHopLe = false;

  @override
  void initState() {
    super.initState();
    _docAnh();
  }

  @override
  void didUpdateWidget(covariant ItemVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _docAnh();
  }

  void _docAnh() {
    _duLieuAnh = null;
    _anhKhongHopLe = false;
    if (!widget.imageUrl.startsWith('data:image/')) return;

    final dauPhanCach = widget.imageUrl.indexOf(',');
    if (dauPhanCach <= 0) {
      _anhKhongHopLe = true;
      return;
    }

    try {
      _duLieuAnh = base64Decode(widget.imageUrl.substring(dauPhanCach + 1));
    } on FormatException {
      _anhKhongHopLe = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _layBieuTuong();
    final anhVatPham = widget.type == 'frame'
        ? layDuongDanKhung(widget.itemId, widget.name)
        : _layDuongDanVatPham();
    if (anhVatPham != null) {
      return _khungAnh(
        Image.asset(
          anhVatPham,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _khungBieuTuong(placeholder),
        ),
      );
    }

    if (widget.imageUrl.isNotEmpty && widget.imageUrl.length <= 4) {
      return _khungBieuTuong(widget.imageUrl);
    }

    if (widget.imageUrl.startsWith('data:image/')) {
      if (_duLieuAnh == null || _anhKhongHopLe) {
        return _khungBieuTuong(placeholder);
      }
      return _khungAnh(
        Image.memory(
          _duLieuAnh!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _khungBieuTuong(placeholder),
        ),
      );
    }

    final uri = Uri.tryParse(widget.imageUrl);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority) {
      return _khungAnh(
        Image.network(
          widget.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _khungBieuTuong(placeholder),
        ),
      );
    }

    return _khungBieuTuong(placeholder);
  }

  String? _layDuongDanVatPham() {
    final nhanDang = '${widget.itemId} ${widget.code} ${widget.name}'
        .toLowerCase();
    if (widget.type == 'help' || widget.type == 'lifeline') {
      if (nhanDang.contains('item_5050') ||
          nhanDang.contains('fifty_fifty') ||
          nhanDang.contains('50/50')) {
        return 'assets/images/items/item_5050.png';
      }
      if (nhanDang.contains('item_extra_time') ||
          nhanDang.contains('extra_time')) {
        return 'assets/images/items/item_extra_time.png';
      }
      if (nhanDang.contains('item_change_q') ||
          nhanDang.contains('change_question')) {
        return 'assets/images/items/item_change_q.png';
      }
    }
    if (widget.type == 'title' &&
        (nhanDang.contains('item_title_master') ||
            nhanDang.contains('master') ||
            nhanDang.contains('cao thủ'))) {
      return 'assets/images/items/item_title_master.png';
    }
    return null;
  }

  String _layBieuTuong() {
    if (widget.type == 'frame') return '🖼️';
    if (widget.type == 'title') return '🏆';

    switch (widget.code.isNotEmpty ? widget.code : widget.itemId) {
      case 'fifty_fifty':
      case 'item_5050':
        return '✂️';
      case 'extra_time':
      case 'item_extra_time':
        return '⏱️';
      case 'change_question':
      case 'item_change_q':
        return '🔄';
      default:
        return widget.type == 'help' || widget.type == 'lifeline' ? '💡' : '✨';
    }
  }

  Widget _khungAnh(Widget image) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }

  Widget _khungBieuTuong(String icon) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(icon, style: TextStyle(fontSize: widget.size * 0.5)),
    );
  }
}
