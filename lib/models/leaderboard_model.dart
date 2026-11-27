// BXH (mục 30) + thống kê Admin (mục 8). Khớp đúng JSON mà
// FastAPI trả về: fastapi/app/routers/leaderboard.py (GET /leaderboard)
// và fastapi/app/routers/admin.py (GET /admin/stats).

class LeaderboardEntry {
  final int rank;
  final String uid;
  final String displayName;
  final String avatarUrl;
  final int score;
  final int plays;

  const LeaderboardEntry({
    required this.rank,
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.score,
    required this.plays,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      plays: (json['plays'] as num?)?.toInt() ?? 0,
    );
  }
}

class QuizSetStat {
  final String quizSetId;
  final String name;
  final int attempts;
  final int avgScore;
  final int maxScore;
  final int minScore;

  const QuizSetStat({
    required this.quizSetId,
    required this.name,
    required this.attempts,
    required this.avgScore,
    required this.maxScore,
    required this.minScore,
  });

  factory QuizSetStat.fromJson(Map<String, dynamic> json) {
    return QuizSetStat(
      quizSetId: json['quizSetId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      avgScore: (json['avgScore'] as num?)?.toInt() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toInt() ?? 0,
      minScore: (json['minScore'] as num?)?.toInt() ?? 0,
    );
  }
}

class TopicStat {
  final String topicId;
  final String name;
  final int attempts;
  final int avgScore;

  const TopicStat({
    required this.topicId,
    required this.name,
    required this.attempts,
    required this.avgScore,
  });

  factory TopicStat.fromJson(Map<String, dynamic> json) {
    return TopicStat(
      topicId: json['topicId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      avgScore: (json['avgScore'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportedQuestion {
  final String questionId;
  final String content;
  final int count;

  const ReportedQuestion({
    required this.questionId,
    required this.content,
    required this.count,
  });

  factory ReportedQuestion.fromJson(Map<String, dynamic> json) {
    return ReportedQuestion(
      questionId: json['questionId'] as String? ?? '',
      content: json['content'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecentAttempt {
  final String userId;
  final String displayName;
  final String quizSetId;
  final String quizSetName;
  final int score;
  final String createdAt;

  const RecentAttempt({
    required this.userId,
    required this.displayName,
    required this.quizSetId,
    required this.quizSetName,
    required this.score,
    required this.createdAt,
  });

  factory RecentAttempt.fromJson(Map<String, dynamic> json) {
    return RecentAttempt(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      quizSetId: json['quizSetId'] as String? ?? '',
      quizSetName: json['quizSetName'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class AdminStats {
  final int users;
  final int quizSets;
  final int questions;
  final int attempts;
  final int pendingReports;
  final List<QuizSetStat> byQuizSet;
  final List<TopicStat> byTopic;
  final List<ReportedQuestion> mostReported;
  final List<RecentAttempt> recentAttempts;

  const AdminStats({
    required this.users,
    required this.quizSets,
    required this.questions,
    required this.attempts,
    required this.pendingReports,
    required this.byQuizSet,
    required this.byTopic,
    required this.mostReported,
    required this.recentAttempts,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? {};
    List<T> parseList<T>(
      Object? raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw is! List) return <T>[];
      return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
    }

    return AdminStats(
      users: (totals['users'] as num?)?.toInt() ?? 0,
      quizSets: (totals['quizSets'] as num?)?.toInt() ?? 0,
      questions: (totals['questions'] as num?)?.toInt() ?? 0,
      attempts: (totals['attempts'] as num?)?.toInt() ?? 0,
      pendingReports: (totals['pendingReports'] as num?)?.toInt() ?? 0,
      byQuizSet: parseList(json['byQuizSet'], QuizSetStat.fromJson),
      byTopic: parseList(json['byTopic'], TopicStat.fromJson),
      mostReported: parseList(
        json['mostReportedQuestions'],
        ReportedQuestion.fromJson,
      ),
      recentAttempts: parseList(json['recentAttempts'], RecentAttempt.fromJson),
    );
  }
}
