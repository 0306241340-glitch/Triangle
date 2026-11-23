class MatchHistoryRecord {
  const MatchHistoryRecord({
    required this.id,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final String opponentName;
  final int myScore;
  final int opponentScore;
  final String result;
  final DateTime? createdAt;

  factory MatchHistoryRecord.fromJson(Map<String, dynamic> json) {
    return MatchHistoryRecord(
      id: json['id']?.toString() ?? '',
      opponentName: json['opponentName'] as String? ?? 'Người chơi',
      myScore: (json['myScore'] as num?)?.toInt() ?? 0,
      opponentScore: (json['opponentScore'] as num?)?.toInt() ?? 0,
      result: json['result'] as String? ?? 'draw',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }
}

class MatchHistoryDetail {
  const MatchHistoryDetail({
    required this.questionId,
    required this.content,
    required this.options,
    required this.correctIndex,
    required this.mySelectedIndex,
    required this.opponentSelectedIndex,
    required this.myCorrect,
    required this.opponentCorrect,
  });

  final String questionId;
  final String content;
  final List<String> options;
  final int correctIndex;
  final int? mySelectedIndex;
  final int? opponentSelectedIndex;
  final bool myCorrect;
  final bool opponentCorrect;

  factory MatchHistoryDetail.fromJson(Map<String, dynamic> json) {
    return MatchHistoryDetail(
      questionId: json['questionId']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      options: (json['options'] as List? ?? [])
          .map((option) => option.toString())
          .toList(),
      correctIndex: (json['correctIndex'] as num?)?.toInt() ?? -1,
      mySelectedIndex: (json['mySelectedIndex'] as num?)?.toInt(),
      opponentSelectedIndex: (json['opponentSelectedIndex'] as num?)?.toInt(),
      myCorrect: json['myCorrect'] as bool? ?? false,
      opponentCorrect: json['opponentCorrect'] as bool? ?? false,
    );
  }
}

class MatchHistoryDetailRecord {
  const MatchHistoryDetailRecord({
    required this.id,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.result,
    required this.createdAt,
    required this.details,
  });

  final String id;
  final String opponentName;
  final int myScore;
  final int opponentScore;
  final String result;
  final DateTime? createdAt;
  final List<MatchHistoryDetail> details;

  factory MatchHistoryDetailRecord.fromJson(Map<String, dynamic> json) {
    return MatchHistoryDetailRecord(
      id: json['id']?.toString() ?? '',
      opponentName: json['opponentName'] as String? ?? 'Người chơi',
      myScore: (json['myScore'] as num?)?.toInt() ?? 0,
      opponentScore: (json['opponentScore'] as num?)?.toInt() ?? 0,
      result: json['result'] as String? ?? 'draw',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      details: (json['details'] as List? ?? [])
          .map(
            (item) => MatchHistoryDetail.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}