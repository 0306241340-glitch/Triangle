class PvpQuestion {
  const PvpQuestion({
    required this.id,
    required this.content,
    required this.options,
  });

  final String id;
  final String content;
  final List<String> options;

  factory PvpQuestion.fromJson(Map<String, dynamic> json) {
    return PvpQuestion(
      id: json['id'] as String,
      content: json['content'] as String,
      options: (json['options'] as List)
          .map((value) => value.toString())
          .toList(),
    );
  }
}

class PvpRoom {
  const PvpRoom({
    required this.id,
    required this.status,
    required this.hostId,
    required this.guestId,
    required this.hostName,
    required this.guestName,
    required this.hostScore,
    required this.guestScore,
    required this.questionIndex,
    required this.questionCount,
    required this.questionSeconds,
    required this.questionStartTime,
    required this.question,
    required this.myAnswered,
    required this.opponentAnswered,
    required this.winnerId,
  });

  final String id;
  final String status;
  final String hostId;
  final String? guestId;
  final String hostName;
  final String guestName;
  final int hostScore;
  final int guestScore;
  final int questionIndex;
  final int questionCount;
  final int questionSeconds;
  final DateTime? questionStartTime;
  final PvpQuestion? question;
  final bool myAnswered;
  final bool opponentAnswered;
  final String? winnerId;

  factory PvpRoom.fromJson(Map<String, dynamic> json) {
    final rawQuestion = json['question'];
    final rawStartTime = json['questionStartTime'];
    return PvpRoom(
      id: json['id'] as String,
      status: json['status'] as String,
      hostId: json['hostId'] as String,
      guestId: json['guestId'] as String?,
      hostName: json['hostName'] as String? ?? 'Người chơi',
      guestName: json['guestName'] as String? ?? 'Đang chờ',
      hostScore: (json['hostScore'] as num?)?.toInt() ?? 0,
      guestScore: (json['guestScore'] as num?)?.toInt() ?? 0,
      questionIndex: (json['questionIndex'] as num?)?.toInt() ?? 0,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      questionSeconds: (json['questionSeconds'] as num?)?.toInt() ?? 15,
      questionStartTime: rawStartTime is String
          ? DateTime.parse(rawStartTime).toUtc()
          : null,
      question: rawQuestion is Map<String, dynamic>
          ? PvpQuestion.fromJson(rawQuestion)
          : null,
      myAnswered: json['myAnswered'] as bool? ?? false,
      opponentAnswered: json['opponentAnswered'] as bool? ?? false,
      winnerId: json['winnerId'] as String?,
    );
  }
}
