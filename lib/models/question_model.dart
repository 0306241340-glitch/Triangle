class Question {
  final String id;
  final String slotId;
  final String topicId;
  final String content;
  final List<String> options;
  final int correctIndex;
  final String level;
  final String explanation;

  const Question({
    required this.id,
    required this.slotId,
    required this.topicId,
    required this.content,
    required this.options,
    required this.correctIndex,
    required this.level,
    required this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String? ?? '',
      slotId: json['slotId']?.toString() ?? '',
      topicId: json['topicId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      options: (json['options'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? -1,
      level: json['level'] as String? ?? 'easy',
      explanation: json['explanation'] as String? ?? '',
    );
  }

  // câu lấy từ API không có đáp án, chỉ dùng để hiển thị
  bool get hasAnswerKey => correctIndex >= 0;

  int get points {
    switch (level) {
      case 'medium':
        return 20;
      case 'hard':
        return 30;
      default:
        return 10;
    }
  }

  int get coins {
    switch (level) {
      case 'medium':
        return 10;
      case 'hard':
        return 15;
      default:
        return 5;
    }
  }

  String get levelLabel {
    switch (level) {
      case 'medium':
        return 'Trung bình';
      case 'hard':
        return 'Khó';
      default:
        return 'Dễ';
    }
  }
}
