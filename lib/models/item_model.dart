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
      lifelineCode: map['lifelineCode']?.toString(),
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