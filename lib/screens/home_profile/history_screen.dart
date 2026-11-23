import 'package:flutter/material.dart';

import '../../models/match_history_model.dart';
import '../../models/quiz_history_model.dart';
import '../../models/quiz_set_model.dart';
import '../../models/topic_model.dart';
import '../../viewmodels/home_profile_vm.dart';
import '../auth_quiz/quiz_play_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.homeViewModel});

  final HomeViewModel homeViewModel;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  HomeViewModel get _vm => widget.homeViewModel;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_loadSelectedTab);
    _vm.loadQuizHistory();
    _vm.loadMatchHistory();
  }

  void _loadSelectedTab() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index == 0 && _vm.quizHistory.isEmpty) {
      _vm.loadQuizHistory(topicId: _vm.historyTopicFilter);
    } else if (_tabs.index == 1 && _vm.matchHistory.isEmpty) {
      _vm.loadMatchHistory();
    }
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_loadSelectedTab)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Lịch sử làm bài'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Chơi đơn'),
              Tab(text: 'Đối kháng 1vs1'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabs,
          children: [_buildQuizHistory(), _buildMatchHistory()],
        ),
      ),
    );
  }

  Widget _buildQuizHistory() {
    final selectedTopic = _vm.historyTopicFilter ?? '';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: DropdownButtonFormField<String>(
            initialValue: selectedTopic,
            decoration: InputDecoration(
              labelText: 'Lọc theo chủ đề',
              prefixIcon: const Icon(Icons.filter_list),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tất cả chủ đề')),
              ..._vm.topics.map(
                (topic) => DropdownMenuItem(
                  value: topic.id,
                  child: Text(topic.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) => _vm.loadQuizHistory(
              topicId: value == null || value.isEmpty ? null : value,
            ),
          ),
        ),
        Expanded(
          child: _historyList(
            isLoading: _vm.isQuizHistoryLoading,
            error: _vm.quizHistoryError,
            isEmpty: _vm.quizHistory.isEmpty,
            emptyMessage: 'Bạn chưa có bài làm nào.',
            onRefresh: () =>
                _vm.loadQuizHistory(topicId: _vm.historyTopicFilter),
            children: _vm.quizHistory
                .map((history) => _quizHistoryCard(history))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchHistory() {
    return _historyList(
      isLoading: _vm.isMatchHistoryLoading,
      error: _vm.matchHistoryError,
      isEmpty: _vm.matchHistory.isEmpty,
      emptyMessage: 'Bạn chưa có trận đối kháng nào.',
      onRefresh: _vm.loadMatchHistory,
      children: _vm.matchHistory
          .map((history) => _matchHistoryCard(history))
          .toList(),
    );
  }

  Widget _historyList({
    required bool isLoading,
    required String? error,
    required bool isEmpty,
    required String emptyMessage,
    required Future<void> Function() onRefresh,
    required List<Widget> children,
  }) {
    if (isLoading && isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Không thể tải lịch sử.\n$error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRefresh, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(child: Text(emptyMessage)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: children,
      ),
    );
  }

  Widget _quizHistoryCard(QuizHistoryRecord history) {
    final quizSet = _quizSetFor(history.quizSetId);
    final topic = _topicFor(history.topicId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                QuizHistoryDetailScreen(homeViewModel: _vm, history: history),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.quiz_outlined, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      quizSet?.title ?? 'Bộ đề ${history.quizSetId}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${history.score} điểm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('📚 ${topic?.name ?? 'Chủ đề'}'),
              const SizedBox(height: 5),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  _HistoryFact(
                    icon: Icons.check_circle_outline,
                    text:
                        '${history.correctCount}/${history.totalCount} câu đúng',
                  ),
                  _HistoryFact(
                    icon: Icons.timer_outlined,
                    text: _formatDuration(history.timeTakenSec),
                  ),
                  _HistoryFact(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDate(history.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _matchHistoryCard(MatchHistoryRecord history) {
    final (label, color) = _resultStyle(history.result);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MatchHistoryDetailScreen(homeViewModel: _vm, history: history),
          ),
        ),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEFF6FF),
            child: Icon(Icons.sports_martial_arts, color: Color(0xFF2563EB)),
          ),
          title: Text('Đối thủ: ${history.opponentName}'),
          subtitle: Text(_formatDate(history.createdAt)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${history.myScore} - ${history.opponentScore}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  QuizSet? _quizSetFor(String id) {
    for (final sets in _vm.quizSetsByTopic.values) {
      for (final set in sets) {
        if (set.id == id) return set;
      }
    }
    return null;
  }

  Topic? _topicFor(String id) {
    for (final topic in _vm.topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }
}

class QuizHistoryDetailScreen extends StatefulWidget {
  const QuizHistoryDetailScreen({
    super.key,
    required this.homeViewModel,
    required this.history,
  });

  final HomeViewModel homeViewModel;
  final QuizHistoryRecord history;

  @override
  State<QuizHistoryDetailScreen> createState() =>
      _QuizHistoryDetailScreenState();
}

class _QuizHistoryDetailScreenState extends State<QuizHistoryDetailScreen> {
  HomeViewModel get _vm => widget.homeViewModel;

  @override
  void initState() {
    super.initState();
    _vm.loadQuizHistoryDetail(widget.history.id);
  }

  @override
  Widget build(BuildContext context) {
    final quizSet = _findQuizSet();
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        final detail = _vm.selectedQuizHistory;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(title: const Text('Chi tiết bài làm')),
          body: _vm.isHistoryDetailLoading
              ? const Center(child: CircularProgressIndicator())
              : _vm.historyDetailError != null
              ? _detailError(_vm.historyDetailError!, () {
                  _vm.loadQuizHistoryDetail(widget.history.id);
                })
              : detail == null
              ? const Center(child: Text('Không có dữ liệu bài làm.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _scoreSummary(
                      score: detail.score,
                      correct: detail.correctCount,
                      total: detail.totalCount,
                      duration: detail.timeTakenSec,
                    ),
                    const SizedBox(height: 12),
                    ...detail.details.asMap().entries.map(
                      (entry) => _quizAnswerCard(entry.key + 1, entry.value),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: quizSet == null
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuizPlayScreen(quizSet: quizSet),
                              ),
                            ),
                      icon: const Icon(Icons.replay),
                      label: const Text('Làm lại bộ đề'),
                    ),
                    if (quizSet == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Bộ đề này hiện không còn trong danh sách để làm lại.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  QuizSet? _findQuizSet() {
    for (final sets in _vm.quizSetsByTopic.values) {
      for (final set in sets) {
        if (set.id == widget.history.quizSetId) return set;
      }
    }
    return null;
  }
}

class MatchHistoryDetailScreen extends StatefulWidget {
  const MatchHistoryDetailScreen({
    super.key,
    required this.homeViewModel,
    required this.history,
  });

  final HomeViewModel homeViewModel;
  final MatchHistoryRecord history;

  @override
  State<MatchHistoryDetailScreen> createState() =>
      _MatchHistoryDetailScreenState();
}

class _MatchHistoryDetailScreenState extends State<MatchHistoryDetailScreen> {
  HomeViewModel get _vm => widget.homeViewModel;

  @override
  void initState() {
    super.initState();
    _vm.loadMatchHistoryDetail(widget.history.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        final detail = _vm.selectedMatchHistory;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(title: const Text('Chi tiết trận đấu')),
          body: _vm.isHistoryDetailLoading
              ? const Center(child: CircularProgressIndicator())
              : _vm.historyDetailError != null
              ? _detailError(_vm.historyDetailError!, () {
                  _vm.loadMatchHistoryDetail(widget.history.id);
                })
              : detail == null
              ? const Center(child: Text('Không có dữ liệu trận đấu.'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(
                              '${detail.myScore} - ${detail.opponentScore}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_resultStyle(detail.result).$1} • ${detail.opponentName}',
                            ),
                            Text(_formatDate(detail.createdAt)),
                          ],
                        ),
                      ),
                    ),
                    ...detail.details.asMap().entries.map(
                      (entry) => _matchQuestionCard(entry.key + 1, entry.value),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _HistoryFact extends StatelessWidget {
  const _HistoryFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: const Color(0xFF64748B)),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
    ],
  );
}

Widget _scoreSummary({
  required int score,
  required int correct,
  required int total,
  required int duration,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryValue('$score', 'điểm'),
          _summaryValue('$correct/$total', 'câu đúng'),
          _summaryValue(_formatDuration(duration), 'thời gian'),
        ],
      ),
    ),
  );
}

Widget _summaryValue(String value, String label) => Column(
  children: [
    Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
  ],
);

Widget _quizAnswerCard(int number, QuizHistoryDetail detail) {
  final isCorrect = detail.isCorrect;
  return Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Câu $number',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (detail.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(detail.content),
          ],
          const SizedBox(height: 8),
          Text('Bạn chọn: ${_answerLabel(detail.selectedIndex)}'),
          Text('Đáp án đúng: ${_answerLabel(detail.correctIndex)}'),
          const SizedBox(height: 4),
          Text(
            isCorrect ? 'Chính xác' : 'Chưa chính xác',
            style: TextStyle(
              color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _matchQuestionCard(int number, MatchHistoryDetail detail) {
  return Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Câu $number',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(detail.content),
          if (detail.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...detail.options.asMap().entries.map(
              (option) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${String.fromCharCode(65 + option.key)}. ${option.value}'
                  '${option.key == detail.correctIndex ? '  ✓' : ''}',
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Bạn: ${_answerLabel(detail.mySelectedIndex)}'
            '${detail.myCorrect ? ' • Đúng' : ''}',
          ),
          Text(
            'Đối thủ: ${_answerLabel(detail.opponentSelectedIndex)}'
            '${detail.opponentCorrect ? ' • Đúng' : ''}',
          ),
        ],
      ),
    ),
  );
}

Widget _detailError(String error, VoidCallback retry) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Không thể tải chi tiết.\n$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

String _answerLabel(int? index) =>
    index == null || index < 0 ? 'Bỏ qua' : 'Đáp án ${index + 1}';

(String, Color) _resultStyle(String result) {
  switch (result) {
    case 'win':
      return ('Thắng', const Color(0xFF16A34A));
    case 'loss':
      return ('Thua', const Color(0xFFDC2626));
    default:
      return ('Hòa', const Color(0xFF64748B));
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${remainingSeconds.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Không rõ thời gian';
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} ${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
