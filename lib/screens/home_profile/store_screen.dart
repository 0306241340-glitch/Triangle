import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/item_model.dart';
import '../../services/store_service.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.service});

  final StoreService? service;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late final StoreService _service;
  StoreCatalog _catalog = StoreCatalog.preview;
  String _selectedType = 'all';
  String? _error;
  String? _purchasingItemId;
  bool _apiAvailable = false;
  bool _isLoading = true;

  static const _categories = {
    'all': 'Tất cả',
    'help': 'Trợ giúp',
    'frame': 'Khung avatar',
    'title': 'Danh hiệu',
  };

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StoreService();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final catalog = await _service.loadCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _apiAvailable = true;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message
            : 'Máy chủ cửa hàng hiện chưa khả dụng. Bạn vẫn có thể xem vật phẩm và giá; giao dịch mua sẽ hoạt động khi kết nối được khôi phục.';
        _apiAvailable = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _showItemDetails(StoreItem item) async {
    final wantsToPurchase = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description),
            const SizedBox(height: 12),
            Text(
              'Giá: ${item.price} xu',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!_apiAvailable) ...[
              const SizedBox(height: 12),
              const Text(
                'Máy chủ cửa hàng chưa khả dụng. Bạn chưa thể mua vật phẩm này.',
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mua'),
          ),
        ],
      ),
    );
    if (wantsToPurchase != true || !mounted) return;
    if (!_apiAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'API cửa hàng chưa hoạt động. Chưa thực hiện giao dịch.',
          ),
        ),
      );
      return;
    }
    await _confirmPurchase(item);
  }

  Future<void> _confirmPurchase(StoreItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận mua'),
        content: Text('Mua ${item.name} với giá ${item.price} xu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mua'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _purchasingItemId = item.id);
    try {
      final result = await _service.purchase(item.id);
      if (!mounted) return;
      final catalog = _catalog;
      setState(() {
        _catalog = catalog.copyWith(
          coins: result.coins,
          ownedQuantities: {
            ...catalog.ownedQuantities,
            item.id: result.quantity,
          },
        );
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã mua ${item.name}.')));
    } catch (error) {
      if (!mounted) return;
      final apiUnavailable =
          error is SocketException ||
          error is HttpException ||
          error is ApiException &&
              (error.statusCode == 404 || error.statusCode >= 500);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mua ${item.name}: $error')),
      );
      if (apiUnavailable) {
        setState(() {
          _apiAvailable = false;
          _error =
              'Máy chủ cửa hàng hiện chưa khả dụng. Bạn vẫn có thể xem vật phẩm và giá; giao dịch mua sẽ hoạt động khi kết nối được khôi phục.';
        });
      }
    } finally {
      if (mounted) setState(() => _purchasingItemId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cửa hàng')),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(child: _buildCatalog(_catalog)),
        ],
      ),
    );
  }

  Widget _buildCatalog(StoreCatalog catalog) {
    final items = catalog.items
        .where((item) => _selectedType == 'all' || item.type == _selectedType)
        .toList();

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) _buildApiNotice(),
          _buildBalance(catalog.coins),
          const SizedBox(height: 16),
          const Text(
            'Vật phẩm',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _selectedType == entry.key,
                    onSelected: (_) =>
                        setState(() => _selectedType = entry.key),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Chưa có vật phẩm trong danh mục này.'),
              ),
            )
          else
            ...items.map((item) => _buildItemCard(item, catalog)),
        ],
      ),
    );
  }

  Widget _buildApiNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFF9A3412)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFF7C2D12)),
            ),
          ),
          IconButton(
            tooltip: 'Kết nối lại',
            onPressed: _loadCatalog,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildBalance(int? coins) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Số dư của bạn',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            coins == null ? 'Chưa tải được' : '$coins xu',
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(StoreItem item, StoreCatalog catalog) {
    final quantity = catalog.ownedQuantities[item.id] ?? 0;
    final isOwned = quantity > 0 && !item.isStackable;
    final isPurchasing = _purchasingItemId == item.id;
    final purchaseInProgress = _purchasingItemId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEFF6FF),
              child: Icon(_iconFor(item.type), color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${item.price} xu'
                    '${quantity > 0 ? ' • Đang có: $quantity' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isOwned)
              const Chip(label: Text('Đã sở hữu'))
            else
              FilledButton(
                onPressed: purchaseInProgress
                    ? null
                    : () => _showItemDetails(item),
                child: isPurchasing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Chi tiết'),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'help':
        return Icons.lightbulb_outline;
      case 'frame':
        return Icons.crop_square;
      case 'title':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.shopping_bag_outlined;
    }
  }
}
