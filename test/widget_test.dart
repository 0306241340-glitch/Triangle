import 'package:flutter_test/flutter_test.dart';
import 'package:do_vui_ai_thuong/main.dart';

void main() {
  test('QuizApp được khởi tạo thành công', () {
    const app = QuizApp();

    expect(app, isA<QuizApp>());
  });
}