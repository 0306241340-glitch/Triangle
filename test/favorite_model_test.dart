import 'package:do_vui_ai_thuong/models/favorite_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses API and legacy favorite field names', () {
    final favorite = FavoriteModel.fromJson({
      'id': 'favorite-1',
      'target_id': 'set-1',
      'target_type': 'quiz_set',
      'created_at': '2026-11-23T10:00:00',
    });

    expect(favorite.targetId, 'set-1');
    expect(favorite.targetType, 'quizSet');
    expect(favorite.createdAt, isNotNull);
    expect(favorite.toJson(), {'targetId': 'set-1', 'targetType': 'quizSet'});
  });
}
