import 'package:do_vui_ai_thuong/models/friend_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('friend request resolves the other participant', () {
    final outgoing = FriendRequest.fromJson('a_b', {
      'userId': 'a',
      'friendId': 'b',
      'status': 'pending',
    });
    final incoming = FriendRequest.fromJson('a_b', {
      'userId': 'a',
      'friendId': 'b',
      'status': 'pending',
    });

    expect(outgoing.otherUserId('a'), 'b');
    expect(incoming.otherUserId('b'), 'a');
  });
}
