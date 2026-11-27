import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/question_model.dart';

enum _ReviewFilter { all, wrong, correct, skipped }

/// Màn S09: Xem lại đáp án ngay sau khi nộp bài.
class QuizReviewScreen extends StatefulWidget {
  const QuizReviewScreen({
    super.key,
    required this.quizTitle,
    required this.questions,
    required this.answers,
    required this.correctIndices,
    required this.score,
    required this.correctCount,
  });

  final String quizTitle;
  final List<Question> questions;
  final Map<int, int> answers;
  final Map<String, int> correctIndices;
  final int score;
  final int correctCount;

  @override
  State<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;

  int? _correctOf(int index) {
    final q = widget.questions[index];
    final fromServer = widget.correctIndices[q.id];
    if (fromServer != null && fromServer >= 0) return fromServer;
    return q.correctIndex >= 0 ? q.correctIndex : null;
  }

  bool _isCorrect(int index) {
    final selected = widget.answers[index];
    final correct = _correctOf(index);
    return selected != null && correct != null && selected == correct;
  }

  bool _isSkipped(int index) => !widget.answers.containsKey(index);

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    final indices = <int>[
      for (var i = 0; i < total; i++)
        if (_filter == _ReviewFilter.all ||
            (_filter == _ReviewFilter.correct && _isCorrect(i)) ||
            (_filter == _ReviewFilter.skipped && _isSkipped(i)) ||
            (_filter == _ReviewFilter.wrong &&
                !_isSkipped(i) &&
                !_isCorrect(i)))
          i,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Xem lại đáp án — ${widget.quizTitle}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Đúng ${widget.correctCount}/$total câu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '+${widget.score} điểm',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _filterChip(_ReviewFilter.all, 'Tất cả ($total)'),
                    _filterChip(_ReviewFilter.wrong, 'Câu sai'),
                    _filterChip(_ReviewFilter.correct, 'Câu đúng'),
                    _filterChip(_ReviewFilter.skipped, 'Bỏ qua'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: indices.isEmpty
                ? const Center(
                    child: Text(
                      'Không có câu hỏi nào trong mục này.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: indices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, pos) =>
                        _buildQuestionCard(indices[pos]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(_ReviewFilter value, String label) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = widget.questions[index];
    final selected = widget.answers[index];
    final correct = _correctOf(index);
    final skipped = selected == null;
    final isRight = !skipped && correct != null && selected == correct;

    final statusColor = skipped
        ? Colors.grey
        : (isRight ? AppColors.success : Colors.red.shade600);
    final statusLabel = skipped
        ? 'Chưa trả lời'
        : (isRight ? 'Đúng' : 'Sai');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Câu ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              q.content,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            for (var optIdx = 0; optIdx < q.options.length; optIdx++)
              _buildOptionTile(
                optIdx: optIdx,
                text: q.options[optIdx],
                isCorrectOpt: correct == optIdx,
                isSelectedOpt: selected == optIdx,
              ),
            if (q.explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Giải thích: ${q.explanation}',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required int optIdx,
    required String text,
    required bool isCorrectOpt,
    required bool isSelectedOpt,
  }) {
    final letter = String.fromCharCode(65 + optIdx);
    Color bg = Colors.white;
    Color border = Colors.grey.shade300;
    Color textColor = Colors.black87;
    IconData? trailingIcon;
    Color? iconColor;

    if (isCorrectOpt) {
      bg = AppColors.success.withOpacity(0.1);
      border = AppColors.success;
      textColor = AppColors.success;
      trailingIcon = Icons.check_circle;
      iconColor = AppColors.success;
    } else if (isSelectedOpt) {
      bg = Colors.red.withOpacity(0.08);
      border = Colors.red.shade400;
      textColor = Colors.red.shade700;
      trailingIcon = Icons.cancel;
      iconColor = Colors.red.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$letter. $text',
              style: TextStyle(
                color: textColor,
                fontWeight: (isCorrectOpt || isSelectedOpt)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(trailingIcon, size: 18, color: iconColor),
          ],
        ],
      ),
    );
  }
}
