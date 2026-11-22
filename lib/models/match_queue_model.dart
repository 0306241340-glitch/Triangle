class MatchQueueState {
  const MatchQueueState({required this.status, this.queueId, this.roomId});

  final String status;
  final String? queueId;
  final String? roomId;

  factory MatchQueueState.fromJson(Map<String, dynamic> json) {
    return MatchQueueState(
      status: json['status'] as String? ?? 'idle',
      queueId: json['queueId'] as String?,
      roomId: json['roomId'] as String?,
    );
  }
}
