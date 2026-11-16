class StoreItem {
  const StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.effect,
    required this.price,
  });

  final String id;
  final String name;
  final String description;
  final String type;
  final String effect;
  final int price;

  bool get isStackable => type == 'help';

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: json['type'] as String,
      effect: json['effect'] as String? ?? '',
      price: (json['price'] as num).toInt(),
    );
  }
}

class StoreCatalog {
  const StoreCatalog({
    required this.coins,
    required this.items,
    required this.ownedQuantities,
  });

  final int? coins;
  final List<StoreItem> items;
  final Map<String, int> ownedQuantities;

  StoreCatalog copyWith({
    int? coins,
    Map<String, int>? ownedQuantities,
  }) {
    return StoreCatalog(
      coins: coins ?? this.coins,
      items: items,
      ownedQuantities: ownedQuantities ?? this.ownedQuantities,
    );
  }

  factory StoreCatalog.fromJson(Map<String, dynamic> json) {
    final inventory = json['inventory'] as Map<String, dynamic>;
    return StoreCatalog(
      coins: (json['coins'] as num).toInt(),
      items: (json['items'] as List)
          .map((item) => StoreItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      ownedQuantities: inventory.map(
        (itemId, quantity) => MapEntry(itemId, (quantity as num).toInt()),
      ),
    );
  }

  static const previewItems = [
    StoreItem(
      id: 'item_5050',
      name: '50/50',
      description: 'Loại bỏ 2 đáp án sai trong câu hỏi hiện tại.',
      type: 'help',
      effect: 'fifty_fifty',
      price: 30,
    ),
    StoreItem(
      id: 'item_extra_time',
      name: 'Thêm thời gian',
      description: 'Cộng thêm 30 giây cho lượt chơi hiện tại.',
      type: 'help',
      effect: 'extra_time',
      price: 20,
    ),
    StoreItem(
      id: 'item_change_q',
      name: 'Đổi câu hỏi',
      description: 'Đổi sang một câu hỏi khác cùng chủ đề.',
      type: 'help',
      effect: 'change_question',
      price: 30,
    ),
    StoreItem(
      id: 'item_frame_gold',
      name: 'Khung avatar Vàng',
      description: 'Khung avatar màu vàng, trang bị ở Hồ sơ.',
      type: 'frame',
      effect: '',
      price: 100,
    ),
    StoreItem(
      id: 'item_title_master',
      name: 'Danh hiệu “Cao thủ”',
      description: 'Danh hiệu hiển thị cạnh tên người chơi.',
      type: 'title',
      effect: '',
      price: 150,
    ),
  ];

  static const preview = StoreCatalog(
    coins: null,
    items: previewItems,
    ownedQuantities: {},
  );
}

class StorePurchaseResult {
  const StorePurchaseResult({
    required this.coins,
    required this.quantity,
  });

  final int coins;
  final int quantity;

  factory StorePurchaseResult.fromJson(Map<String, dynamic> json) {
    return StorePurchaseResult(
      coins: (json['coins'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
    );
  }
}