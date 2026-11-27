import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/question_model.dart';
import '../../models/quiz_set_model.dart';
import '../../viewmodels/auth_quiz_vm.dart';
import 'quiz_review_screen.dart';

typedef _SubmitQuestionReport = Future<String?> Function(
  String issueType,
  String description,
  String answerText,
);

class _QuestionReportDialog extends StatefulWidget {
  const _QuestionReportDialog({required this.question, required this.onSubmit});

  final Question question;
  final _SubmitQuestionReport onSubmit;

  @override
  State<_QuestionReportDialog> createState() => _QuestionReportDialogState();
}

class _QuestionReportDialogState extends State<_QuestionReportDialog> {
  final _descriptionController = TextEditingController();
  String _issueType = 'question';
  int? _answerIndex;
  String? _validationError;
  bool _isSending = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.length < 5) {
      setState(() => _validationError = 'Mô tả cần ít nhất 5 ký tự.');
      return;
    }
    if (_issueType == 'answer' && _answerIndex == null) {
      setState(() => _validationError = 'Hãy chọn đáp án cần báo lỗi.');
      return;
    }

    setState(() {
      _isSending = true;
      _validationError = null;
    });
    final answerText = _answerIndex == null
        ? ''
        : widget.question.options[_answerIndex!];
    final error = await widget.onSubmit(_issueType, description, answerText);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isSending = false;
        _validationError = 'Gửi báo lỗi thất bại: $error';
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Báo lỗi câu hỏi/đáp án'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bạn muốn báo lỗi phần nào?'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Câu hỏi'),
                  selected: _issueType == 'question',
                  onSelected: (_) => setState(() {
                    _issueType = 'question';
                    _validationError = null;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Đáp án'),
                  selected: _issueType == 'answer',
                  onSelected: (_) => setState(() {
                    _issueType = 'answer';
                    _validationError = null;
                  }),
                ),
              ],
            ),
            if (_issueType == 'answer') ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _answerIndex,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Đáp án cần báo lỗi',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (
                    var index = 0;
                    index < widget.question.options.length;
                    index++
                  )
                    DropdownMenuItem(
                      value: index,
                      child: Text(
                        '${String.fromCharCode(65 + index)}. ${widget.question.options[index]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  _answerIndex = value;
                  _validationError = null;
                }),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mô tả lỗi',
                hintText: 'Cho biết câu hỏi hoặc đáp án sai ở đâu',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_validationError != null)
              Text(
                _validationError!,
                style: const TextStyle(color: AppColors.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _isSending ? null : _submit,
          child: _isSending
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Đang gửi...'),
                  ],
                )
              : const Text('Gửi báo lỗi'),
        ),
      ],
    );
  }
}

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
    _vm.load(widget.quizSet.id, topicId: widget.quizSet.topicId);
  }

  // ──── Hàm dùng chung: gọi trợ giúp → hiện SnackBar nếu lỗi ────
  Future<void> _useHelp(Future<String?> Function() action) async {
    final err = await action();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _reportQuestion(Question question) async {
    final didReport = await showDialog<bool>(
      context: context,
      builder: (_) => _QuestionReportDialog(
        question: question,
        onSubmit: (issueType, description, answerText) => _vm.reportQuestion(
          questionId: question.id,
          issueType: issueType,
          description: description,
          answerText: answerText,
        ),
      ),
    );
    if (didReport != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi báo lỗi. Cảm ơn bạn!')),
    );
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizReviewScreen(
                    quizTitle: widget.quizSet.title,
                    questions: _vm.questions,
                    answers: Map<int, int>.from(_vm.answers),
                    correctIndices: Map<String, int>.from(_vm.correctIndices),
                    score: _vm.score,
                    correctCount: _vm.correctCount,
                  ),
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
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _vm.error ?? 'Không tải được câu hỏi từ máy chủ.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _vm.load(
                        widget.quizSet.id,
                        topicId: widget.quizSet.topicId,
                      ),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
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
                if (_vm.submitError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Chưa lưu được kết quả: ${_vm.submitError}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _reportQuestion(q),
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const Text('Báo lỗi câu hỏi/đáp án'),
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
                          inventoryCount: _vm.helpCount('fifty_fifty'),
                          used: _vm.hiddenOptions.containsKey(_vm.currentIndex),
                          loading: _vm.activeHelp == 'fifty_fifty',
                          disabled: _vm.isUsingHelp,
                          onTap: () =>
                              _useHelp(() async => _vm.useFiftyFifty()),
                        ),
                        // ── 2. Đổi câu hỏi (30 xu) ──
                        _HelpButton(
                          icon: Icons.swap_horiz,
                          label: 'Đổi câu',
                          cost: 30,
                          inventoryCount: _vm.helpCount('change_question'),
                          used: _vm.changedQuestions.contains(_vm.currentIndex),
                          loading: _vm.activeHelp == 'change_question',
                          disabled: _vm.isUsingHelp,
                          onTap: () =>
                              _useHelp(() async => _vm.useChangeQuestion()),
                        ),
                        // ── 3. Thêm thời gian (20 xu) ──
                        _HelpButton(
                          icon: Icons.more_time,
                          label: '+30s',
                          cost: 20,
                          inventoryCount: _vm.helpCount('extra_time'),
                          used: _vm.usedExtraTime,
                          loading: _vm.activeHelp == 'extra_time',
                          disabled: _vm.isUsingHelp,
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
                    SizedBox(
                      width: 100,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _vm.currentIndex == 0
                            ? null
                            : () => _vm.goTo(_vm.currentIndex - 1),
                        child: const Text('← Trước'),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 110,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _vm.isLast
                              ? AppColors.success
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: _vm.isLast
                            ? (_vm.isSubmitting ? null : () => _vm.submit())
                            : () => _vm.goTo(_vm.currentIndex + 1),
                        child: _vm.isLast && _vm.isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text('Đang nộp...'),
                                ],
                              )
                            : Text(_vm.isLast ? 'Nộp bài' : 'Sau →'),
                      ),
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
    this.inventoryCount = 0,
    this.loading = false,
    this.disabled = false,
  });

  final IconData icon;
  final String label;
  final int cost;
  final int inventoryCount;
  final bool used;
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasItem = !used && inventoryCount > 0;
    final color = used
        ? Colors.grey
        : (hasItem ? AppColors.success : AppColors.accent);
    return InkWell(
      onTap: (used || disabled) ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: used
              ? Colors.grey.shade100
              : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: used
                ? Colors.grey.shade300
                : color.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
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
              used
                  ? '(Hết)'
                  : (hasItem ? '(Còn $inventoryCount)' : '($cost🪙)'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: used ? FontWeight.normal : FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
