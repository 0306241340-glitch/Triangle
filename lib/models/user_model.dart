import 'package:cloud_firestore/cloud_firestore.dart';

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

  UserModel({
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
  });

  // Chuyển đổi dữ liệu từ Map (Firestore) sang UserModel
  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    final rawName = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?) ?? '';

    return UserModel(
      uid: uid,
      email: email,
      displayName: (rawName != null && rawName.isNotEmpty)
          ? rawName
          : (email.isNotEmpty ? email.split('@').first : 'Người chơi'),
      avatarUrl: data['avatarUrl'] as String?,
      userCode: (data['userCode'] as String?) ?? '------',
      role: (data['role'] as String?) ?? 'user',
      status: (data['status'] as String?) ?? 'active',
      coins: (data['coins'] as num?)?.toInt() ?? 100,
      score: (data['score'] as num?)?.toInt() ?? 0,
      weeklyScore: (data['weeklyScore'] as num?)?.toInt() ?? 0,
      streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Đóng gói UserModel thành Map để lưu lên Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'userCode': userCode,
      'role': role,
      'status': status,
      'coins': coins,
      'score': score,
      'weeklyScore': weeklyScore,
      'streakDays': streakDays,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}