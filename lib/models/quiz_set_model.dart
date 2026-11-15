// Model Bộ đề — khớp collection `quiz_sets` trong Firestore.
// File này TV1 An giữ. level: 'easy' | 'medium' | 'hard' (Dễ / Trung bình / Khó).
class QuizSet {
  final String id;
  final String topicId;
  final String title;
  final String level;
  final int questionCount;
  final int durationSec;
  final int attemptCount;
  final double avgScore;

  const QuizSet({
    required this.id,
    required this.topicId,
    required this.title,
    required this.level,
    required this.questionCount,
    required this.durationSec,
    required this.attemptCount,
    required this.avgScore,
  });

  factory QuizSet.fromJson(Map<String, dynamic> json) {
    return QuizSet(
      id: json['id'] as String? ?? '',
      topicId: json['topicId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      level: json['level'] as String? ?? 'easy',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 300,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      avgScore: (json['avgScore'] as num?)?.toDouble() ?? 0,
    );
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
