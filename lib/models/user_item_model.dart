class UserItemModel {
  final String id;
  final String userId;
  final String itemId;
  final int quantity;
  final bool equipped;

  UserItemModel({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.quantity,
    this.equipped = false,
  });

  factory UserItemModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserItemModel(
      id: docId,
      userId: (map['userId'] ?? '').toString(),
      itemId: (map['itemId'] ?? '').toString(),
      quantity: (map['quantity'] is num) ? (map['quantity'] as num).toInt() : 0,
      equipped: map['equipped'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'itemId': itemId,
      'quantity': quantity,
      'equipped': equipped,
    };
  }
}