class Topic {
  final String id;
  final String name;
  final String description;
  final String icon; // emoji hiển thị, vd: 📐
  final int questionCount;
  final String imageUrl;
  final bool isActive;

  const Topic({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.questionCount,
    this.imageUrl = '',
    this.isActive = true,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '📚',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      imageUrl: (json['imageUrl'] ?? json['image_url']) as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'questionCount': questionCount,
    'imageUrl': imageUrl,
    'isActive': isActive,
  };
}
