class PvpInvitation {
  const PvpInvitation({
    required this.roomId,
    required this.notificationId,
    required this.hostId,
    required this.hostName,
    this.createdAt,
  });

  final String roomId;
  final String notificationId;
  final String hostId;
  final String hostName;
  final DateTime? createdAt;

  factory PvpInvitation.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    return PvpInvitation(
      roomId: json['roomId'] as String,
      notificationId: json['notificationId'] as String,
      hostId: json['hostId'] as String,
      hostName: json['hostName'] as String? ?? 'Người chơi',
      createdAt: rawCreatedAt is String
          ? DateTime.parse(rawCreatedAt).toLocal()
          : null,
    );
  }
}
