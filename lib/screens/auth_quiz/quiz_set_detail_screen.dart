
import 'package:flutter/material.dart';

import '../../models/quiz_set_model.dart';
import '../../models/review_model.dart';
import '../../models/topic_model.dart';
import 'quiz_play_screen.dart';

class QuizSetDetailScreen extends StatelessWidget {
  const QuizSetDetailScreen({
    super.key,
    required this.quizSet,
    required this.topic,
  });

  final QuizSet quizSet;
  final Topic topic;

  // bộ 10 câu chuẩn tối đa 180đ
  int get maxScore => 180;

  @override
  Widget build(BuildContext context) {
    final stats = <_Stat>[
      _Stat('Chủ đề', topic.name),
      _Stat('Số câu', '${quizSet.questionCount} câu'),
      _Stat('Thời gian', '${quizSet.durationSec ~/ 60} phút'),
      _Stat('Độ khó', quizSet.levelLabel),
      _Stat('Điểm tối đa', '$maxScore điểm'),
      _Stat('Lượt làm', '${quizSet.attemptCount} lượt'),
      _Stat('Điểm trung bình', quizSet.avgScore.toStringAsFixed(1)),
      _Stat(
        'Mô tả',
        quizSet.description.isEmpty
            ? 'Bộ đề ${topic.name}'
            : quizSet.description,
      ),
      _Stat('Yêu thích', '🤍 Thêm vào yêu thích'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(quizSet.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...stats.map(
            (s) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                s.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(s.value),
            ),
          ),
          const Divider(),
          const Text(
            'Đánh giá',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._mockReviews.map(
            (r) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(r.userName[0])),
                title: Text(r.userName),
                subtitle: Text(r.comment),
                trailing: Text('⭐' * r.rating),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizPlayScreen(quizSet: quizSet),
                  ),
                );
              },
              child: const Text('Trả lời bộ đề'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
}

// đánh giá mẫu
const _mockReviews = [
  Review(
    id: 'r1',
    quizSetId: 'set_math_1',
    userName: 'Ngọc',
    rating: 5,
    comment: 'Bộ đề hay, câu hỏi rõ ràng, giải thích dễ hiểu.',
    createdAt: '2026-11-14',
  ),
  Review(
    id: 'r2',
    quizSetId: 'set_math_1',
    userName: 'Vương',
    rating: 4,
    comment: 'Câu khó hơi ít, mong thêm câu nâng cao.',
    createdAt: '2026-11-14',
  ),
  Review(
    id: 'r3',
    quizSetId: 'set_math_1',
    userName: 'An',
    rating: 5,
    comment: 'Làm xong 10 câu được 180 điểm, rất đã.',
    createdAt: '2026-11-15',
  ),
];
