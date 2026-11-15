// Model Chủ đề — khớp collection `topics` trong Firestore (xem database/thiet-ke-database-firestore.md).
// File này TV1 An giữ. Dữ liệu mẫu 3 chủ đề lấy từ seed-data.json.
class Topic {
  final String id;
  final String name;
  final String description;
  final String icon; // emoji hiển thị, vd: 📐
  final int questionCount;

  const Topic({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.questionCount,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '📚',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'questionCount': questionCount,
      };
}
