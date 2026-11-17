class QuizSet {
  final String id;
  final String topicId;
  final String title;
  final String level;
  final int questionCount;
  final int durationSec;
  final int attemptCount;
  final double avgScore;
  final String description;

  const QuizSet({
    required this.id,
    required this.topicId,
    required this.title,
    required this.level,
    required this.questionCount,
    required this.durationSec,
    required this.attemptCount,
    required this.avgScore,
    required this.description,
  });

  factory QuizSet.fromJson(Map<String, dynamic> json) {
    return QuizSet(
      id: json['id'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      title: (json['title'] ?? json['name']) as String? ?? '',
      level: json['level'] as String? ?? 'mixed',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 300,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      avgScore: (json['avgScore'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
    );
  }

  String get levelLabel {
    switch (level) {
      case 'medium':
        return 'Trung bình';
      case 'hard':
        return 'Khó';
      case 'easy':
        return 'Dễ';
      default:
        return 'Tổng hợp';
    }
  }
}
