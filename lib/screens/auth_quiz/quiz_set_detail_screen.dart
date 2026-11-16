import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/quiz_set_model.dart';
import '../../models/review_model.dart';
import '../../models/topic_model.dart';
import 'quiz_play_screen.dart';

class QuizSetDetailScreen extends StatefulWidget {
  const QuizSetDetailScreen({
    super.key,
    required this.quizSet,
    required this.topic,
  });

  final QuizSet quizSet;
  final Topic topic;

  @override
  State<QuizSetDetailScreen> createState() => _QuizSetDetailScreenState();
}

class _QuizSetDetailScreenState extends State<QuizSetDetailScreen> {
  bool _isFavorite = false;

  // bộ 10 câu chuẩn tối đa 180đ, ghi cứng tạm
  int get maxScore => 180;

  Color get levelColor => AppColors.levelColor(widget.quizSet.level);

  @override
  Widget build(BuildContext context) {
    final quizSet = widget.quizSet;
    final topic = widget.topic;
    return Scaffold(
      appBar: AppBar(
        title: Text(quizSet.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // thẻ tiêu đề + mô tả + huy hiệu độ khó
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          quizSet.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          quizSet.levelLabel,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: levelColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quizSet.description.isEmpty
                        ? 'Bộ đề ${topic.name}'
                        : quizSet.description,
                  ),
                  Text(
                    'Chủ đề: ${topic.name}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 2 hàng ô thống kê, mỗi hàng 3 cột — đồng bộ màu trắng hết
          Row(
            children: [
              _StatBox(label: 'Số câu', value: '${quizSet.questionCount} câu'),
              _StatBox(
                label: 'Thời gian',
                value: '${quizSet.durationSec ~/ 60} phút',
              ),
              _StatBox(label: 'Độ khó', value: quizSet.levelLabel),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatBox(label: 'Điểm tối đa', value: '$maxScore điểm'),
              _StatBox(
                label: 'Lượt làm',
                value: '${quizSet.attemptCount} lượt',
              ),
              _StatBox(
                label: 'Điểm TB',
                value: quizSet.avgScore.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 2 nút ngay dưới ô thống kê
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizPlayScreen(quizSet: quizSet),
                        ),
                      );
                    },
                    child: const Text('Bắt đầu làm bài'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isFavorite
                        ? AppColors.error
                        : AppColors.primary,
                    side: BorderSide(
                      color: _isFavorite ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _isFavorite = !_isFavorite);
                  },
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? AppColors.error : AppColors.primary,
                  ),
                  label: Text(_isFavorite ? 'Đã thích' : 'Yêu thích'),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
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
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// đánh giá mẫu, đánh giá thật cần API
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
