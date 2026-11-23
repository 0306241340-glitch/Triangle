import 'package:do_vui_ai_thuong/models/match_history_model.dart';
import 'package:do_vui_ai_thuong/models/quiz_history_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses quiz history summaries and answer details', () {
    final history = QuizHistoryRecord.fromJson({
      'id': 'history-1',
      'quizSetId': 'set-1',
      'topicId': 'topic-1',
      'score': 20,
      'correctCount': 1,
      'totalCount': 2,
      'coinsEarned': 10,
      'timeTakenSec': 42,
      'createdAt': '2026-11-23T10:00:00',
    });
    final detail = QuizHistoryDetail.fromJson({
      'questionId': 'question-1',
      'content': 'Question?',
      'selectedIndex': 2,
      'correctIndex': 2,
      'isCorrect': true,
      'level': 'medium',
    });

    expect(history.score, 20);
    expect(history.timeTakenSec, 42);
    expect(detail.content, 'Question?');
    expect(detail.isCorrect, isTrue);
  });

  test('parses match results and question answer snapshots', () {
    final history = MatchHistoryRecord.fromJson({
      'id': 'match-1',
      'opponentName': 'Bạn chơi',
      'myScore': 10,
      'opponentScore': 0,
      'result': 'win',
    });
    final detail = MatchHistoryDetail.fromJson({
      'questionId': 'question-1',
      'content': 'Question?',
      'options': ['A', 'B'],
      'correctIndex': 1,
      'mySelectedIndex': 1,
      'opponentSelectedIndex': null,
      'myCorrect': true,
      'opponentCorrect': false,
    });

    expect(history.result, 'win');
    expect(history.opponentName, 'Bạn chơi');
    expect(detail.options, ['A', 'B']);
    expect(detail.mySelectedIndex, 1);
    expect(detail.opponentSelectedIndex, isNull);
  });
}
