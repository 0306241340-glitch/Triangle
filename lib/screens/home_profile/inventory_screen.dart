import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import '../../models/user_item_model.dart';
import '../../services/store_service.dart';
import '../../widgets/item_visual.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _storeService = StoreService();

  bool _isLoading = true;
  String? _errorMessage;
  String? _equippedFrameId;
  String? _equippedTitleId;

  List<MapEntry<UserItemModel, ItemModel>> _lifelines = [];
  List<MapEntry<UserItemModel, ItemModel>> _frames = [];
  List<MapEntry<UserItemModel, ItemModel>> _titles = [];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Vui lòng đăng nhập để xem túi đồ.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Chỉ tải song song 2 collection nhẹ (bỏ qua users/{uid} chứa ảnh Base64 nặng)
      final results = await Future.wait([
        _firestore.collection('items').where('isActive', isEqualTo: true).get(),
        _firestore
            .collection('user_items')
            .where('userId', isEqualTo: user.uid)
            .get(),
      ]).timeout(const Duration(seconds: 4));

      final itemsSnap = results[0];
      final userItemsSnap = results[1];

      final itemCatalog = <String, ItemModel>{};
      for (final doc in itemsSnap.docs) {
        itemCatalog[doc.id] = ItemModel.fromMap(doc.data(), doc.id);
      }

      final lifelines = <MapEntry<UserItemModel, ItemModel>>[];
      final frames = <MapEntry<UserItemModel, ItemModel>>[];
      final titles = <MapEntry<UserItemModel, ItemModel>>[];

      String? activeFrameId;
      String? activeTitleId;

      for (final doc in userItemsSnap.docs) {
        final ui = UserItemModel.fromMap(doc.data(), doc.id);
        if (ui.quantity <= 0) continue;

        final detail = itemCatalog[ui.itemId];
        if (detail == null) continue;

        if (detail.type == 'frame') {
          if (ui.equipped) activeFrameId = detail.id;
          frames.add(MapEntry(ui, detail));
        } else if (detail.type == 'title') {
          if (ui.equipped) activeTitleId = detail.id;
          titles.add(MapEntry(ui, detail));
        } else {
          lifelines.add(MapEntry(ui, detail));
        }
      }

      if (!mounted) return;
      setState(() {
        _equippedFrameId = activeFrameId;
        _equippedTitleId = activeTitleId;
        _lifelines = lifelines;
        _frames = frames;
        _titles = titles;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Không thể tải túi đồ: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Kết nối mạng máy ảo bị chậm hoặc gián đoạn. Bấm "Thử lại" để tải.';
      });
    }
  }

  Future<void> _toggleEquip({
    required ItemModel targetItem,
    required bool isCurrentlyEquipped,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final nextEquipped = !isCurrentlyEquipped;
      await _storeService.setEquipped(targetItem.id, equipped: nextEquipped);

      if (!mounted) return;
      setState(() {
        if (targetItem.type == 'frame') {
          _equippedFrameId = nextEquipped ? targetItem.id : null;
        } else if (targetItem.type == 'title') {
          _equippedTitleId = nextEquipped ? targetItem.id : null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextEquipped
                ? 'Đã trang bị "${targetItem.name}"'
                : 'Đã gỡ trang bị "${targetItem.name}"',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật trang bị: $e')),
      );
    }
  }

  void _goToShop() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang chuyển sang Cửa hàng đổi xu...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _lifelines.isEmpty && _frames.isEmpty && _titles.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Túi đồ',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _isLoading ? null : _loadInventory,
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox.expand(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off_rounded,
                          size: 44,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadInventory,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎒', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text(
                          'Túi đồ của bạn đang trống',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Hãy ghé Cửa hàng để dùng xu đổi quyền trợ giúp, khung avatar và danh hiệu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _goToShop,
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Đến Cửa hàng'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInventory,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (_lifelines.isNotEmpty) ...[
                        _buildSectionTitle('Quyền trợ giúp'),
                        ..._lifelines.map(
                          (e) => _buildCard(
                            userItem: e.key,
                            item: e.value,
                            isEquipped: false,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_frames.isNotEmpty) ...[
                        _buildSectionTitle('Khung ảnh đại diện'),
                        ..._frames.map(
                          (e) => _buildCard(
                            userItem: e.key,
                            item: e.value,
                            isEquipped: _equippedFrameId == e.value.id,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_titles.isNotEmpty) ...[
                        _buildSectionTitle('Danh hiệu'),
                        ..._titles.map(
                          (e) => _buildCard(
                            userItem: e.key,
                            item: e.value,
                            isEquipped: _equippedTitleId == e.value.id,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildCard({
    required UserItemModel userItem,
    required ItemModel item,
    required bool isEquipped,
  }) {
    final isEquippable = item.type == 'frame' || item.type == 'title';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isEquipped ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
          width: isEquipped ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ItemVisual(
              imageUrl: item.imageUrl,
              type: item.type,
              code: item.lifelineCode ?? '',
              itemId: item.id,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isEquippable)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: ElevatedButton(
                  onPressed: () => _toggleEquip(
                    targetItem: item,
                    isCurrentlyEquipped: isEquipped,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped
                        ? const Color(0xFFE0E7FF)
                        : const Color(0xFF1E3A8A),
                    foregroundColor: isEquipped
                        ? const Color(0xFF3730A3)
                        : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isEquipped ? 'Đang dùng' : 'Trang bị',
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'x${userItem.quantity}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
