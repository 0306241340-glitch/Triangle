import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/item_model.dart';
import '../../models/leaderboard_model.dart';
import '../../models/question_model.dart';
import '../../models/quiz_set_model.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../viewmodels/admin_vm.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen>
    with SingleTickerProviderStateMixin {
  late final AdminViewModel _vm;
  late final TabController _tabController;
  int _lastTab = 0;

  @override
  void initState() {
    super.initState();
    _vm = AdminViewModel();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(_onTabChanged);
    _vm.loadTab(0);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || _lastTab == _tabController.index) {
      return;
    }
    _lastTab = _tabController.index;
    _vm.loadTab(_lastTab);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Quản trị hệ thống',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Bộ đề'),
            Tab(text: 'Vật phẩm'),
            Tab(text: 'Tài khoản'),
            Tab(text: 'Báo lỗi'),
            Tab(text: 'Thống kê'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => TabBarView(
          controller: _tabController,
          children: [
            _buildQuizSetsTab(),
            _buildItemsTab(),
            _buildUsersTab(),
            _buildReportsTab(),
            _buildStatsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSetsTab() {
    return _collectionTab(
      isLoading: _vm.isLoadingQuizSets,
      error: _vm.quizSetsError,
      hasData: _vm.quizSets.isNotEmpty,
      onRefresh: _vm.loadQuizSets,
      emptyMessage: 'Chưa có bộ đề.',
      children: _vm.quizSets.map(_quizSetCard).toList(),
    );
  }

  Widget _quizSetCard(QuizSet quizSet) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.library_books, color: AppColors.primary),
        title: Text(
          quizSet.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${quizSet.levelLabel} • ${quizSet.questionCount} câu • ${quizSet.attemptCount} lượt thi • ${quizSet.isActive ? 'Đang hoạt động' : 'Đã ẩn'}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        onExpansionChanged: (expanded) {
          if (expanded) _vm.loadQuestions(quizSet);
        },
        children: [
          ListTile(
            dense: true,
            title: Text('Câu hỏi theo chủ đề ${quizSet.topicId}'),
          ),
          if (quizSet.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  quizSet.description,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          _buildQuestions(quizSet),
        ],
      ),
    );
  }

  Widget _buildQuestions(QuizSet quizSet) {
    if (_vm.loadingQuestionSets.contains(quizSet.id)) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = _vm.questionErrors[quizSet.id];
    if (error != null) {
      return ListTile(
        title: Text(error),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _vm.loadQuestions(quizSet),
        ),
      );
    }
    final questions = _vm.questionsByQuizSet[quizSet.id];
    if (questions == null) return const SizedBox.shrink();
    if (questions.isEmpty) {
      return const ListTile(title: Text('Chủ đề này chưa có câu hỏi.'));
    }
    return Column(
      children: questions.map((question) => _questionTile(question)).toList(),
    );
  }

  Widget _questionTile(Question question) {
    return ExpansionTile(
      dense: true,
      title: Text(
        question.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(question.levelLabel),
      children: [
        for (var index = 0; index < question.options.length; index++)
          ListTile(
            dense: true,
            leading: Icon(
              index == question.correctIndex
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: index == question.correctIndex
                  ? Colors.green
                  : AppColors.textSecondary,
            ),
            title: Text(question.options[index]),
          ),
        if (question.explanation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Giải thích: ${question.explanation}'),
            ),
          ),
      ],
    );
  }

  Widget _buildItemsTab() {
    return _collectionTab(
      isLoading: _vm.isLoadingItems,
      error: _vm.itemsError,
      hasData: _vm.items.isNotEmpty,
      onRefresh: _vm.loadItems,
      emptyMessage: 'Chưa có vật phẩm.',
      children: _vm.items.map(_itemCard).toList(),
    );
  }

  Widget _itemCard(ItemModel item) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.card_giftcard, color: AppColors.primary),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          [
            if (item.description.isNotEmpty) item.description,
            'Loại: ${item.type} • Giá: ${item.price} xu',
            'Trạng thái: ${item.isActive ? 'Đang bán' : 'Đã ẩn'}',
          ].join('\n'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildUsersTab() {
    return _collectionTab(
      isLoading: _vm.isLoadingUsers,
      error: _vm.usersError,
      hasData: _vm.users.isNotEmpty,
      onRefresh: _vm.loadUsers,
      emptyMessage: 'Chưa có tài khoản.',
      children: _vm.users.map(_userCard).toList(),
    );
  }

  Widget _userCard(UserModel user) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            user.displayName.isEmpty ? '?' : user.displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${user.email}\n${user.role} • ${user.status} • ${user.gamesPlayed} lượt chơi',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        isThreeLine: true,
        trailing: Text(
          '${user.coins} xu',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return _collectionTab(
      isLoading: _vm.isLoadingReports,
      error: _vm.reportsError,
      hasData: _vm.reports.isNotEmpty,
      onRefresh: _vm.loadReports,
      emptyMessage: 'Chưa có báo lỗi.',
      children: _vm.reports.map(_reportCard).toList(),
    );
  }

  Widget _reportCard(ReportModel report) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined, color: AppColors.accentDark),
        title: Text(
          report.questionContent.isEmpty
              ? 'Câu hỏi ${report.questionId}'
              : report.questionContent,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          [
            if (report.reason.isNotEmpty) report.reason,
            'Người gửi: ${report.userName.isEmpty ? report.userId : report.userName}',
          ].join('\n'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        isThreeLine: true,
        trailing: Chip(
          label: Text(_reportStatus(report.status)),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  String _reportStatus(String status) {
    switch (status) {
      case 'resolved':
        return 'Đã xử lý';
      case 'rejected':
        return 'Đã từ chối';
      default:
        return 'Chờ xử lý';
    }
  }

  Widget _buildStatsTab() {
    final stats = _vm.stats;
    return _collectionTab(
      isLoading: _vm.isLoadingStats,
      error: _vm.statsError,
      hasData: stats != null,
      onRefresh: _vm.loadStats,
      emptyMessage: 'Chưa có dữ liệu thống kê.',
      children: stats == null ? const [] : _statsContent(stats),
    );
  }

  List<Widget> _statsContent(AdminStats stats) {
    return [
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _TotalCard(
            label: 'Người dùng',
            value: stats.users,
            icon: Icons.people,
          ),
          _TotalCard(
            label: 'Bộ đề',
            value: stats.quizSets,
            icon: Icons.library_books,
          ),
          _TotalCard(
            label: 'Câu hỏi',
            value: stats.questions,
            icon: Icons.question_answer,
          ),
          _TotalCard(
            label: 'Lượt thi',
            value: stats.attempts,
            icon: Icons.play_circle_filled,
          ),
        ],
      ),
      if (stats.pendingReports > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Chip(
            avatar: const Icon(
              Icons.flag,
              color: AppColors.accentDark,
              size: 18,
            ),
            label: Text(
              '${stats.pendingReports} báo lỗi chờ xử lý',
              style: const TextStyle(
                color: AppColors.accentDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Điểm theo bộ đề',
        children: stats.byQuizSet.map(
          (quizSet) => ListTile(
            title: Text(
              quizSet.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${quizSet.attempts} lượt thi • TB ${quizSet.avgScore} • Cao nhất ${quizSet.maxScore}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Điểm theo chủ đề',
        children: stats.byTopic.map(
          (topic) => ListTile(
            title: Text(
              topic.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${topic.attempts} lượt thi • TB ${topic.avgScore}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Câu bị báo lỗi nhiều nhất',
        children: stats.mostReported.map(
          (report) => ListTile(
            title: Text(
              report.content.isEmpty ? report.questionId : report.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            trailing: Text(
              '${report.count} báo lỗi',
              style: const TextStyle(
                color: AppColors.accentDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SectionCard(
        title: 'Lượt thi gần đây',
        children: stats.recentAttempts.map(
          (attempt) => ListTile(
            title: Text(
              attempt.displayName.isEmpty ? 'Người chơi' : attempt.displayName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              attempt.quizSetName,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            trailing: Text(
              '${attempt.score} điểm',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _collectionTab({
    required bool isLoading,
    required String? error,
    required bool hasData,
    required Future<void> Function() onRefresh,
    required String emptyMessage,
    required List<Widget> children,
  }) {
    if (isLoading && !hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && !hasData) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error, textAlign: TextAlign.center),
            ),
            FilledButton(onPressed: onRefresh, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error,
                style: const TextStyle(color: AppColors.accentDark),
              ),
            ),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text(emptyMessage)),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final Iterable<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
