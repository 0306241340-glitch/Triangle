class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.userCode,
    required this.displayName,
    required this.avatarUrl,
  });

  final String uid;
  final String userCode;
  final String displayName;
  final String avatarUrl;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      uid: json['uid'] as String,
      userCode: json['userCode'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Người chơi',
      avatarUrl: json['avatarUrl'] as String? ?? '',
    );
  }
}

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
  });

  final String id;
  final String userId;
  final String friendId;
  final String status;

  String otherUserId(String currentUserId) =>
      userId == currentUserId ? friendId : userId;

  factory FriendRequest.fromJson(String id, Map<String, dynamic> json) {
    return FriendRequest(
      id: id,
      userId: json['userId'] as String,
      friendId: json['friendId'] as String,
      status: json['status'] as String? ?? 'pending',
    );
  }
}