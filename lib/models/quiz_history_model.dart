class QuizHistoryRecord {
  const QuizHistoryRecord({
    required this.id,
    required this.quizSetId,
    required this.topicId,
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.coinsEarned,
    required this.timeTakenSec,
    required this.createdAt,
  });

  final String id;
  final String quizSetId;
  final String topicId;
  final int score;
  final int correctCount;
  final int totalCount;
  final int coinsEarned;
  final int timeTakenSec;
  final DateTime? createdAt;

  factory QuizHistoryRecord.fromJson(Map<String, dynamic> json) {
    return QuizHistoryRecord(
      id: json['id']?.toString() ?? '',
      quizSetId: json['quizSetId']?.toString() ?? '',
      topicId: json['topicId']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coinsEarned'] as num?)?.toInt() ?? 0,
      timeTakenSec: (json['timeTakenSec'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class QuizHistoryDetail {
  const QuizHistoryDetail({
    required this.questionId,
    required this.content,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isCorrect,
    required this.level,
  });

  final String questionId;
  final String content;
  final int selectedIndex;
  final int correctIndex;
  final bool isCorrect;
  final String level;

  factory QuizHistoryDetail.fromJson(Map<String, dynamic> json) {
    return QuizHistoryDetail(
      questionId: json['questionId']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      selectedIndex: (json['selectedIndex'] as num?)?.toInt() ?? -1,
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? -1,
      isCorrect: json['isCorrect'] as bool? ?? false,
      level: json['level'] as String? ?? 'easy',
    );
  }
}

class QuizHistoryDetailRecord {
  const QuizHistoryDetailRecord({
    required this.id,
    required this.quizSetId,
    required this.score,
    required this.correctCount,
    required this.totalCount,
    required this.coinsEarned,
    required this.timeTakenSec,
    required this.details,
  });

  final String id;
  final String quizSetId;
  final int score;
  final int correctCount;
  final int totalCount;
  final int coinsEarned;
  final int timeTakenSec;
  final List<QuizHistoryDetail> details;

  factory QuizHistoryDetailRecord.fromJson(Map<String, dynamic> json) {
    return QuizHistoryDetailRecord(
      id: json['id']?.toString() ?? '',
      quizSetId: json['quizSetId']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coinsEarned'] as num?)?.toInt() ?? 0,
      timeTakenSec: (json['timeTakenSec'] as num?)?.toInt() ?? 0,
      details: (json['details'] as List? ?? [])
          .map(
            (item) => QuizHistoryDetail.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}