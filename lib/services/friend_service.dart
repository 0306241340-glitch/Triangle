import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/app_constants.dart';
import '../models/friend_model.dart';

class FriendService {
  FriendService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _uid;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Bạn cần đăng nhập để quản lý bạn bè.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _friends =>
      _firestore.collection(AppConstants.friendsCollection);

  Future<void> ensurePublicProfile() async {
    final uid = _uid;
    final userSnapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!userSnapshot.exists) {
      throw StateError('Không tìm thấy hồ sơ người dùng.');
    }

    final user = userSnapshot.data()!;
    final userCode = user['userCode'] as String?;
    if (userCode == null || userCode.isEmpty) {
      throw StateError('Tài khoản chưa có mã kết bạn.');
    }

    final profileRef = _firestore
        .collection(AppConstants.publicProfilesCollection)
        .doc(uid);
    final profile = {
      'uid': uid,
      'userCode': userCode,
      'displayName': user['displayName'] as String? ?? 'Người chơi',
      'displayNameLower': (user['displayName'] as String? ?? 'Người chơi')
          .toLowerCase(),
      'avatarUrl': user['avatarUrl'] as String? ?? '',
    };

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(profileRef);
      if (existing.exists) {
        if (existing.data()?['uid'] != uid) {
          throw StateError(
            'Hồ sơ công khai không khớp với tài khoản hiện tại.',
          );
        }
        return;
      }
      transaction.set(profileRef, profile);
    });
  }

  Future<List<PublicProfile>> searchUsers(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length < 2) {
      throw ArgumentError('Nhập ít nhất 2 ký tự để tìm bạn bè.');
    }

    await ensurePublicProfile();
    final collection = _firestore.collection(
      AppConstants.publicProfilesCollection,
    );
    final results = <String, PublicProfile>{};

    final codeSnapshot = await collection
        .where('userCode', isEqualTo: normalized.toUpperCase())
        .limit(1)
        .get();
    for (final doc in codeSnapshot.docs) {
      final profile = PublicProfile.fromJson(doc.data());
      if (profile.uid != _uid) results[profile.uid] = profile;
    }

    final nameSnapshot = await collection
        .where('displayNameLower', isGreaterThanOrEqualTo: normalized)
        .where('displayNameLower', isLessThanOrEqualTo: '$normalized\uf8ff')
        .limit(20)
        .get();
    for (final doc in nameSnapshot.docs) {
      final profile = PublicProfile.fromJson(doc.data());
      if (profile.uid != _uid) results[profile.uid] = profile;
    }

    return results.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchIncomingRequests() {
    return _friends
        .where('friendId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOutgoingRequests() {
    return _friends
        .where('userId', isEqualTo: _uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFriendsAsSender() {
    return _friends
        .where('userId', isEqualTo: _uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFriendsAsRecipient() {
    return _friends
        .where('friendId', isEqualTo: _uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  Future<PublicProfile?> getPublicProfile(String uid) async {
    final snapshot = await _firestore
        .collection(AppConstants.publicProfilesCollection)
        .doc(uid)
        .get();
    if (!snapshot.exists) return null;
    return PublicProfile.fromJson(snapshot.data()!);
  }

  Future<void> sendRequest(String recipientUid) async {
    final uid = _uid;
    if (recipientUid == uid) {
      throw StateError('Bạn không thể tự kết bạn với chính mình.');
    }

    final members = [uid, recipientUid]..sort();
    final requestRef = _friends.doc('${members[0]}_${members[1]}');
    final profile = await getPublicProfile(recipientUid);
    if (profile == null) {
      throw StateError('Không tìm thấy tài khoản này.');
    }

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(requestRef);
      if (existing.exists) {
        final request = FriendRequest.fromJson(existing.id, existing.data()!);
        if (request.status == 'accepted') {
          throw StateError('Hai bạn đã là bạn bè.');
        }
        if (request.friendId == uid) {
          throw StateError('Người này đã gửi lời mời kết bạn cho bạn.');
        }
        throw StateError('Bạn đã gửi lời mời cho người này rồi.');
      }

      transaction.set(requestRef, {
        'userId': uid,
        'friendId': recipientUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> acceptRequest(String requestId) async {
    await _friends.doc(requestId).update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRequest(String requestId) =>
      _friends.doc(requestId).delete();

  Future<void> removeFriend(String requestId) =>
      _friends.doc(requestId).delete();

  Future<void> cancelRequest(String requestId) =>
      _friends.doc(requestId).delete();
}
