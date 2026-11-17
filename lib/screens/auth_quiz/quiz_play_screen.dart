import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
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

  // ──── Hàm dùng chung: gọi trợ giúp → hiện SnackBar nếu lỗi ────
  Future<void> _useHelp(Future<String?> Function() action) async {
    final err = await action();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  // ──── Dialog kết quả ────
  void _onSubmitted() {
    if (!_vm.submitted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: AppColors.accent, size: 28),
            SizedBox(width: 8),
            Text(
              'Kết quả bài thi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Đúng: ${_vm.correctCount}/${_vm.total} câu',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            if (_vm.skippedCount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.help_outline, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Bỏ qua: ${_vm.skippedCount} câu',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng điểm:', style: TextStyle(fontSize: 15)),
                Text(
                  '+${_vm.score} điểm',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Xu nhận được:', style: TextStyle(fontSize: 15)),
                Text(
                  '+${_vm.coins} 🪙',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Màn Xem lại S09 — Ngọc đang làm'),
                ),
              );
            },
            child: const Text('Xem lại đáp án'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 44),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
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
            appBar: AppBar(
              title: Text(widget.quizSet.title),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final q = _vm.currentQuestion;
        if (q == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.quizSet.title),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(child: Text('Không tải được câu hỏi')),
          );
        }
        final selected = _vm.answers[_vm.currentIndex];
        final isUrgent = _vm.remainingSec < 60;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.quizSet.title),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            actions: [
              // ── Xu hiện có ──
              Container(
                margin: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 3),
                    Text(
                      '${_vm.userCoins}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Đồng hồ đếm ngược ──
              Container(
                margin: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? AppColors.error.withOpacity(0.2)
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUrgent ? AppColors.error : Colors.white30,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: isUrgent ? AppColors.error : AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _vm.timeText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUrgent ? AppColors.error : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Thanh tiến độ ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_vm.currentIndex + 1) / _vm.total,
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: const Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(height: 14),
                // ── Thông tin câu hỏi ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Câu ${_vm.currentIndex + 1}/${_vm.total}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.levelColor(q.level)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            q.levelLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.levelColor(q.level),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '+${q.points} điểm',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── Phần nội dung câu hỏi + 4 đáp án có thể cuộn nếu màn hình nhỏ ──
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Nội dung câu hỏi ──
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                q.content,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── 4 phương án trả lời ──
                        ...List.generate(q.options.length, (i) {
                          if (_vm.isHidden(_vm.currentIndex, i)) {
                            return const SizedBox.shrink();
                          }
                          final isChosen = selected == i;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isChosen
                                      ? AppColors.primary.withOpacity(0.08)
                                      : Colors.white,
                                  side: BorderSide(
                                    color: isChosen
                                        ? AppColors.primary
                                        : const Color(0xFFCBD5E1),
                                    width: isChosen ? 2 : 1,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _vm.selectAnswer(i),
                                child: Text(
                                  '${String.fromCharCode(65 + i)}. ${q.options[i]}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isChosen
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isChosen
                                        ? AppColors.primary
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ════════════════════════════════════════════════
                //  3 QUYỀN TRỢ GIÚP (BF03 - Thiết kế gọn gàng, tinh tế)
                // ════════════════════════════════════════════════
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // ── 1. 50/50 (30 xu) ──
                        _HelpButton(
                          icon: Icons.filter_2,
                          label: '50/50',
                          cost: 30,
                          used: _vm.hiddenOptions.containsKey(_vm.currentIndex),
                          onTap: () =>
                              _useHelp(() async => _vm.useFiftyFifty()),
                        ),
                        // ── 2. Đổi câu hỏi (30 xu) ──
                        _HelpButton(
                          icon: Icons.swap_horiz,
                          label: 'Đổi câu',
                          cost: 30,
                          used: _vm.changedQuestions.contains(_vm.currentIndex),
                          onTap: () =>
                              _useHelp(() async => _vm.useChangeQuestion()),
                        ),
                        // ── 3. Thêm thời gian (20 xu) ──
                        _HelpButton(
                          icon: Icons.more_time,
                          label: '+30s',
                          cost: 20,
                          used: _vm.usedExtraTime,
                          onTap: () => _useHelp(() async => _vm.useExtraTime()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Hàng nút điều hướng ──
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 44),
                      ),
                      onPressed: _vm.currentIndex == 0
                          ? null
                          : () => _vm.goTo(_vm.currentIndex - 1),
                      child: const Text('← Trước'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(110, 44),
                        backgroundColor: _vm.isLast
                            ? AppColors.success
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                      ),
                      onPressed: _vm.isLast
                          ? () => _vm.submit()
                          : () => _vm.goTo(_vm.currentIndex + 1),
                      child: Text(_vm.isLast ? 'Nộp bài' : 'Sau →'),
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

/// Widget nút trợ giúp nhỏ gọn dạng pill/chip — không chiếm nhiều diện tích.
class _HelpButton extends StatelessWidget {
  const _HelpButton({
    required this.icon,
    required this.label,
    required this.cost,
    required this.used,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int cost;
  final bool used;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = used ? Colors.grey : AppColors.accent;
    return InkWell(
      onTap: used ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: used
              ? Colors.grey.shade100
              : AppColors.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: used
                ? Colors.grey.shade300
                : AppColors.accent.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              used ? '(Hết)' : '($cost🪙)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: used ? FontWeight.normal : FontWeight.bold,
                color: used ? Colors.grey : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
