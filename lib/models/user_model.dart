class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String userCode;
  final String role;
  final String status;
  final int coins;
  final int score;
  final int weeklyScore;
  final int streakDays;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? frameId;
  final String? frameName;
  final String? titleId;
  final String? titleName;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.userCode,
    this.role = 'user',
    this.status = 'active',
    this.coins = 100,
    this.score = 0,
    this.weeklyScore = 0,
    this.streakDays = 0,
    this.createdAt,
    this.updatedAt,
    this.frameId,
    this.frameName,
    this.titleId,
    this.titleName,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    final rawName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?) ?? '';
    final equippedItems = (data['equippedItems'] as List? ?? [])
        .whereType<Map<String, dynamic>>();
    final frames = equippedItems.where((item) => item['type'] == 'frame');
    final titles = equippedItems.where((item) => item['type'] == 'title');
    final frame = frames.isEmpty ? null : frames.first;
    final title = titles.isEmpty ? null : titles.first;

    return UserModel(
      uid: uid,
      email: email,
      displayName: rawName?.isNotEmpty == true
          ? rawName!
          : (email.isNotEmpty ? email.split('@').first : 'Người chơi'),
      avatarUrl: data['avatarUrl'] as String?,
      userCode: data['userCode'] as String? ?? '------',
      role: data['role'] as String? ?? 'user',
      status: data['status'] as String? ?? 'active',
      coins: (data['coins'] as num?)?.toInt() ?? 100,
      score: (data['score'] as num?)?.toInt() ?? 0,
      weeklyScore: (data['weeklyScore'] as num?)?.toInt() ?? 0,
      streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
      gamesPlayed: (data['gamesPlayed'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
      frameId: frame?['itemId'] as String?,
      frameName: frame?['name'] as String?,
      titleId: title?['itemId'] as String?,
      titleName: title?['name'] as String?,
    );
  }
}
