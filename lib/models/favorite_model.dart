class FavoriteModel {
  const FavoriteModel({
    required this.id,
    required this.targetId,
    required this.targetType,
    this.createdAt,
  });

  final String id;
  final String targetId;
  final String targetType;
  final DateTime? createdAt;

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    final rawTargetType =
        (json['targetType'] ?? json['target_type'] ?? '').toString();
    return FavoriteModel(
      id: json['id']?.toString() ?? '',
      targetId: (json['targetId'] ?? json['target_id'])?.toString() ?? '',
      targetType: rawTargetType == 'quiz_set' ? 'quizSet' : rawTargetType,
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['created_at'] ?? json['createAt'])
                ?.toString() ??
            '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'targetId': targetId,
    'targetType': targetType,
  };
}