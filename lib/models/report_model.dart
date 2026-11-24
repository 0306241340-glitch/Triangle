class ReportModel {
  const ReportModel({
    required this.id,
    required this.questionId,
    required this.questionContent,
    required this.userId,
    required this.userName,
    required this.reason,
    required this.status,
  });

  final int id;
  final String questionId;
  final String questionContent;
  final String userId;
  final String userName;
  final String reason;
  final String status;

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      questionId: map['questionId']?.toString() ?? '',
      questionContent: map['questionContent']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
    );
  }
}
