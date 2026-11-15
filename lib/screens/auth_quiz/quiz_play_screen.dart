// Màn Làm bài (S07) — TV1 An giữ, thẻ [Mục 14-17] một mình An làm.
// Chuyển câu, đếm ngược tổng thời gian, trợ giúp 50/50, nộp bài.
// Hết giờ tự nộp. Nộp xong hiện kết quả (điểm/xu/số câu đúng); màn Kết quả
// đầy đủ S08 là của Ngọc — nút "Xem lại đáp án" sẽ mở S09 khi Ngọc làm xong.
import 'package:flutter/material.dart';

import '../../models/quiz_set_model.dart';
import '../../viewmodels/auth_quiz_vm.dart';

class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({super.key, required this.quizSet});

  final QuizSet quizSet;

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  late final QuizPlayViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = QuizPlayViewModel();
    _vm.addListener(_onSubmitted);
    _vm.load(widget.quizSet.id);
  }

  void _onSubmitted() {
    if (!_vm.submitted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Kết quả'),
        content: Text(
          'Đúng ${_vm.correctCount}/${_vm.total} câu\n'
          'Điểm: ${_vm.score}\nXu nhận: ${_vm.coins}',
        ),
        actions: [
          TextButton(
            // TODO: mở màn Xem lại S09 khi Ngọc làm xong
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Màn Xem lại S09 — Ngọc đang làm')),
              );
            },
            child: const Text('Xem lại đáp án'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // đóng dialog
              Navigator.pop(context); // về Chi tiết bộ đề
            },
            child: const Text('Về Trang chủ'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _vm.removeListener(_onSubmitted);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.quizSet.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final q = _vm.currentQuestion;
        if (q == null) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.quizSet.title)),
            body: const Center(child: Text('Không tải được câu hỏi')),
          );
        }
        final selected = _vm.answers[_vm.currentIndex];
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.quizSet.title),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '⏱ ${_vm.timeText}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _vm.remainingSec < 60 ? Colors.red : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: (_vm.currentIndex + 1) / _vm.total,
                ),
                const SizedBox(height: 12),
                Text(
                  'Câu ${_vm.currentIndex + 1}/${_vm.total} · ${q.levelLabel} · ${q.points} điểm',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(q.content, style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                ...List.generate(q.options.length, (i) {
                  if (_vm.isHidden(_vm.currentIndex, i)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selected == i
                              ? const Color(0xFF2563EB).withOpacity(0.15)
                              : null,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(14),
                        ),
                        onPressed: () => _vm.selectAnswer(i),
                        child: Text(
                          '${String.fromCharCode(65 + i)}. ${q.options[i]}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _vm.currentIndex == 0
                          ? null
                          : () => _vm.goTo(_vm.currentIndex - 1),
                      child: const Text('← Câu trước'),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      // 50/50: ẩn 2 đáp án sai, tốn 30 xu
                      onPressed: () => _vm.useFiftyFifty(),
                      child: const Text('50/50 · 30 xu'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _vm.isLast
                          ? () => _vm.submit()
                          : () => _vm.goTo(_vm.currentIndex + 1),
                      child: Text(_vm.isLast ? 'Nộp bài' : 'Câu sau →'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
