class StoreItem {
  const StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.effect,
    required this.price,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String description;
  final String type;
  final String effect;
  final int price;
  final String imageUrl;

  bool get isStackable => type == 'help' || type == 'lifeline';

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: json['type'] as String,
      effect: (json['effect'] ?? json['lifelineCode'])?.toString() ?? '',
      price: (json['price'] as num).toInt(),
      imageUrl: json['imageUrl']?.toString() ?? '',
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

  StoreCatalog copyWith({int? coins, Map<String, int>? ownedQuantities}) {
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
}

class StorePurchaseResult {
  const StorePurchaseResult({required this.coins, required this.quantity});

  final int coins;
  final int quantity;

  factory StorePurchaseResult.fromJson(Map<String, dynamic> json) {
    return StorePurchaseResult(
      coins: (json['coins'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
    );
  }
}

class ItemModel {
  final String id;
  final String name;
  final String type;
  final String? lifelineCode;
  final int price;
  final String description;
  final String imageUrl;
  final bool isActive;

  ItemModel({
    required this.id,
    required this.name,
    required this.type,
    this.lifelineCode,
    required this.price,
    required this.description,
    required this.imageUrl,
    this.isActive = true,
  });

  factory ItemModel.fromMap(Map<String, dynamic> map, String docId) {
    return ItemModel(
      id: docId,
      name: (map['name'] ?? '').toString(),
      type: (map['type'] ?? 'lifeline').toString(),
      lifelineCode: (map['effect'] ?? map['lifelineCode'])?.toString(),
      price: (map['price'] is num) ? (map['price'] as num).toInt() : 0,
      description: (map['description'] ?? '').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'lifelineCode': lifelineCode,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }
}
