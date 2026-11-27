import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/item_model.dart';
import '../../models/leaderboard_model.dart';
import '../../models/question_model.dart';
import '../../models/quiz_set_model.dart';
import '../../models/report_model.dart';
import '../../models/topic_model.dart';
import '../../models/user_model.dart';
import '../../viewmodels/admin_vm.dart';
import 'admin_edit_dialogs.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen>
    with SingleTickerProviderStateMixin {
  late final AdminViewModel _vm;
  late final TabController _tabController;
  late final TextEditingController _userSearchController;
  late final TextEditingController _questionSearchController;
  Timer? _questionSearchDebounce;
  int _quizManagementSection = 0;
  String _questionTopicFilter = '';
  String _questionLevelFilter = '';
  int _lastTab = 0;

  @override
  void initState() {
    super.initState();
    _vm = AdminViewModel();
    _userSearchController = TextEditingController();
    _questionSearchController = TextEditingController();
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
    _questionSearchDebounce?.cancel();
    _userSearchController.dispose();
    _questionSearchController.dispose();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(
            spacing: 8,
            children: [
              _managementChip('Bộ đề', 0),
              _managementChip('Chủ đề', 1),
              _managementChip('Ngân hàng câu hỏi', 2),
            ],
          ),
        ),
        Expanded(
          child: switch (_quizManagementSection) {
            1 => _buildTopicsTab(),
            2 => _buildQuestionBankTab(),
            _ => _buildQuizSetList(),
          },
        ),
      ],
    );
  }

  Widget _managementChip(String label, int section) {
    return ChoiceChip(
      label: Text(label),
      selected: _quizManagementSection == section,
      onSelected: (selected) {
        if (!selected) return;
        setState(() => _quizManagementSection = section);
        if (section == 0) {
          _vm.loadQuizSets();
        } else {
          _vm.loadTopics();
          if (section == 2) _loadQuestionBank();
        }
      },
    );
  }

  Widget _buildQuizSetList() {
    return _collectionTab(
      isLoading: _vm.isLoadingQuizSets,
      error: _vm.quizSetsError,
      hasData: _vm.quizSets.isNotEmpty,
      onRefresh: _vm.loadQuizSets,
      emptyMessage: 'Chưa có bộ đề.',
      header: _addButton('Thêm bộ đề', () => _editQuizSet()),
      children: _vm.quizSets.map(_quizSetCard).toList(),
    );
  }

  Widget _quizSetCard(QuizSet quizSet) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.library_books, color: AppColors.primary),
        title: Row(
          children: [
            Expanded(
              child: Text(
                quizSet.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _popupMenu([
              _menuAction('edit', 'Sửa'),
              _menuAction(
                'toggle',
                quizSet.isActive ? 'Ẩn bộ đề' : 'Hiện bộ đề',
              ),
              _menuAction('delete', 'Xóa'),
            ], (action) => _quizSetAction(quizSet, action)),
          ],
        ),
        subtitle: Text(
          '${quizSet.levelLabel} • ${quizSet.questionCount} câu • ${quizSet.attemptCount} lượt thi • ${quizSet.isActive ? 'Đang hoạt động' : 'Đã ẩn'} • ${quizSet.selectionMode == 'manual' ? 'Chọn thủ công' : 'Ngẫu nhiên'}',
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

  Widget _buildTopicsTab() {
    return _collectionTab(
      isLoading: _vm.isLoadingTopics,
      error: _vm.topicsError,
      hasData: _vm.topics.isNotEmpty,
      onRefresh: _vm.loadTopics,
      emptyMessage: 'Chưa có chủ đề.',
      header: _addButton('Thêm chủ đề', () => _editTopic()),
      children: _vm.topics.map(_topicCard).toList(),
    );
  }

  Widget _topicCard(Topic topic) {
    return Card(
      child: ListTile(
        leading: Text(topic.icon.isEmpty ? '📚' : topic.icon),
        title: Text(
          topic.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${topic.description}\n${topic.questionCount} câu hỏi • ${topic.isActive ? 'Đang hiển thị' : 'Đã ẩn'}',
        ),
        isThreeLine: true,
        trailing: _popupMenu([
          _menuAction('edit', 'Sửa'),
          _menuAction('toggle', topic.isActive ? 'Ẩn chủ đề' : 'Hiện chủ đề'),
          _menuAction('delete', 'Xóa'),
        ], (action) => _topicAction(topic, action)),
      ),
    );
  }

  Widget _buildQuestionBankTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _questionTopicFilter,
                decoration: const InputDecoration(
                  labelText: 'Lọc theo chủ đề',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Tất cả chủ đề'),
                  ),
                  ..._vm.topics.map(
                    (topic) => DropdownMenuItem(
                      value: topic.id,
                      child: Text(topic.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  _questionTopicFilter = value ?? '';
                  _loadQuestionBank();
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Tìm nội dung câu hỏi',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (_) {
                        _questionSearchDebounce?.cancel();
                        _questionSearchDebounce = Timer(
                          const Duration(milliseconds: 350),
                          _loadQuestionBank,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _questionLevelFilter,
                    hint: const Text('Độ khó'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Tất cả')),
                      DropdownMenuItem(value: 'easy', child: Text('Dễ')),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Text('Trung bình'),
                      ),
                      DropdownMenuItem(value: 'hard', child: Text('Khó')),
                    ],
                    onChanged: (value) {
                      setState(() => _questionLevelFilter = value ?? '');
                      _loadQuestionBank();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _collectionTab(
            isLoading: _vm.isLoadingQuestionBank,
            error: _vm.questionBankError,
            hasData: _vm.questionBank.isNotEmpty,
            onRefresh: _loadQuestionBank,
            emptyMessage: 'Chưa có câu hỏi.',
            header: _addButton(
              'Thêm câu hỏi',
              () => _editQuestion(initialTopicId: _questionTopicFilter),
            ),
            children: _vm.questionBank.map(_questionBankCard).toList(),
          ),
        ),
      ],
    );
  }

  Widget _questionBankCard(Question question) {
    return Card(
      child: ExpansionTile(
        title: Text(question.content, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${question.levelLabel} • ${question.isActive ? 'Đang sử dụng' : 'Đã ẩn'}',
        ),
        trailing: _popupMenu([
          _menuAction('edit', 'Sửa'),
          _menuAction('toggle', question.isActive ? 'Ẩn câu hỏi' : 'Hiện câu hỏi'),
          _menuAction('delete', 'Xóa'),
        ], (action) => _questionAction(question, action)),
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
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Giải thích: ${question.explanation}'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadQuestionBank() => _vm.loadQuestionBank(
    topicId: _questionTopicFilter,
    search: _questionSearchController.text.trim(),
    level: _questionLevelFilter,
  );

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
      header: _addButton('Thêm vật phẩm', () => _editItem()),
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
        trailing: _popupMenu([
          _menuAction('edit', 'Sửa'),
          _menuAction('toggle', item.isActive ? 'Ngừng bán' : 'Bán lại'),
          _menuAction('delete', 'Xóa'),
        ], (action) => _itemAction(item, action)),
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              hintText: 'Tìm tên, email, UID hoặc mã người dùng',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => _vm.loadUsers(
                  search: _userSearchController.text.trim(),
                ),
              ),
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => _vm.loadUsers(search: value.trim()),
          ),
        ),
        Expanded(
          child: _collectionTab(
            isLoading: _vm.isLoadingUsers,
            error: _vm.usersError,
            hasData: _vm.users.isNotEmpty,
            onRefresh: () => _vm.loadUsers(),
            emptyMessage: 'Chưa có tài khoản.',
            children: _vm.users.map(_userCard).toList(),
          ),
        ),
      ],
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${user.coins} xu',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(
              user.status == 'locked' ? Icons.lock : Icons.lock_open,
              size: 18,
              color: user.status == 'locked' ? Colors.red : Colors.green,
            ),
          ],
        ),
        onTap: () => _toggleUserStatus(user),
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
        onTap: () => _reportActions(report),
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

  Widget _addButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(label),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuAction(String value, String label) =>
      PopupMenuItem(value: value, child: Text(label));

  Widget _popupMenu(
    List<PopupMenuItem<String>> actions,
    ValueChanged<String> onSelected,
  ) {
    return PopupMenuButton<String>(
      itemBuilder: (_) => actions,
      onSelected: onSelected,
    );
  }

  Future<void> _runMutation(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    final success = await _vm.performMutation(action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? successMessage
              : (_vm.mutationError ?? 'Thao tác thất bại.'),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editQuizSet([QuizSet? existing]) async {
    if (_vm.topics.isEmpty) await _vm.loadTopics();
    if (!mounted) return;
    if (_vm.topics.isEmpty) {
      _showMessage(_vm.topicsError ?? 'Hãy tạo chủ đề trước.');
      return;
    }
    final body = await showQuizSetEditor(
      context,
      topics: _vm.topics,
      loadQuestions: _vm.questionsForTopic,
      quizSet: existing,
    );
    if (body == null) return;
    await _runMutation(() async {
      await _vm.saveQuizSet(existing?.id, body);
      await _vm.loadQuizSets();
    }, successMessage: existing == null ? 'Đã tạo bộ đề.' : 'Đã cập nhật bộ đề.');
  }

  Future<void> _quizSetAction(QuizSet quizSet, String action) async {
    if (action == 'edit') return _editQuizSet(quizSet);
    if (action == 'toggle') {
      return _runMutation(() async {
        await _vm.saveQuizSet(quizSet.id, {
          'topicId': quizSet.topicId,
          'title': quizSet.title,
          'description': quizSet.description,
          'level': quizSet.level,
          'durationSec': quizSet.durationSec,
          'questionCount': quizSet.questionCount,
          'isActive': !quizSet.isActive,
          'selectionMode': quizSet.selectionMode,
          'questionIds': quizSet.questionIds,
        });
        await _vm.loadQuizSets();
      }, successMessage: 'Đã cập nhật trạng thái bộ đề.');
    }
    if (action == 'delete' &&
        await _confirm('Xóa bộ đề?', 'Thao tác này không thể hoàn tác.')) {
      await _runMutation(() => _vm.deleteQuizSet(quizSet.id),
          successMessage: 'Đã xóa bộ đề.');
    }
  }

  Future<void> _editTopic([Topic? topic]) async {
    final body = await showTopicEditor(context, topic: topic);
    if (body == null) return;
    await _runMutation(() async {
      await _vm.saveTopic(topic?.id, body);
      await _vm.loadTopics();
    }, successMessage: topic == null ? 'Đã tạo chủ đề.' : 'Đã cập nhật chủ đề.');
  }

  Future<void> _topicAction(Topic topic, String action) async {
    if (action == 'edit') return _editTopic(topic);
    if (action == 'toggle') {
      return _runMutation(() async {
        await _vm.saveTopic(topic.id, {
          'name': topic.name,
          'description': topic.description,
          'icon': topic.icon,
          'imageUrl': topic.imageUrl,
          'isActive': !topic.isActive,
        });
        await _vm.loadTopics();
      }, successMessage: 'Đã cập nhật trạng thái chủ đề.');
    }
    if (action == 'delete' &&
        await _confirm(
          'Xóa chủ đề?',
          'Không thể xóa chủ đề đang có bộ đề hoặc câu hỏi.',
        )) {
      await _runMutation(() => _vm.deleteTopic(topic.id),
          successMessage: 'Đã xóa chủ đề.');
    }
  }

  Future<void> _editQuestion({
    Question? question,
    String? initialTopicId,
  }) async {
    if (_vm.topics.isEmpty) await _vm.loadTopics();
    if (!mounted) return;
    if (_vm.topics.isEmpty) {
      _showMessage(_vm.topicsError ?? 'Hãy tạo chủ đề trước.');
      return;
    }
    final body = await showQuestionEditor(
      context,
      topics: _vm.topics,
      question: question,
      initialTopicId: initialTopicId,
    );
    if (body == null) return;
    await _runMutation(() async {
      await _vm.saveQuestion(question?.id, body);
      await _loadQuestionBank();
    }, successMessage: question == null ? 'Đã tạo câu hỏi.' : 'Đã cập nhật câu hỏi.');
  }

  Future<void> _questionAction(Question question, String action) async {
    if (action == 'edit') return _editQuestion(question: question);
    if (action == 'toggle') {
      return _runMutation(() async {
        await _vm.saveQuestion(question.id, {
          'topicId': question.topicId,
          'content': question.content,
          'options': question.options,
          'correctIndex': question.correctIndex,
          'level': question.level,
          'explanation': question.explanation,
          'isActive': !question.isActive,
        });
        await _loadQuestionBank();
      }, successMessage: 'Đã cập nhật trạng thái câu hỏi.');
    }
    if (action == 'delete' &&
        await _confirm(
          'Xóa câu hỏi?',
          'Không thể xóa câu hỏi đã được dùng trong bộ đề hoặc lượt thi.',
        )) {
      await _runMutation(() async {
        await _vm.deleteQuestion(question.id);
        await _loadQuestionBank();
      }, successMessage: 'Đã xóa câu hỏi.');
    }
  }

  Future<void> _editItem([ItemModel? item]) async {
    final body = await showItemEditor(context, item: item);
    if (body == null) return;
    await _runMutation(() async {
      await _vm.saveItem(item?.id, body);
      await _vm.loadItems();
    }, successMessage: item == null ? 'Đã tạo vật phẩm.' : 'Đã cập nhật vật phẩm.');
  }

  Future<void> _itemAction(ItemModel item, String action) async {
    if (action == 'edit') return _editItem(item);
    if (action == 'toggle') {
      return _runMutation(() async {
        await _vm.saveItem(item.id, {
          'name': item.name,
          'type': item.type,
          'lifelineCode': item.lifelineCode ?? '',
          'price': item.price,
          'description': item.description,
          'isActive': !item.isActive,
        });
        await _vm.loadItems();
      }, successMessage: 'Đã cập nhật trạng thái vật phẩm.');
    }
    if (action == 'delete' &&
        await _confirm('Xóa vật phẩm?', 'Thao tác này không thể hoàn tác.')) {
      await _runMutation(() => _vm.deleteItem(item.id),
          successMessage: 'Đã xóa vật phẩm.');
    }
  }

  Future<void> _toggleUserStatus(UserModel user) async {
    final nextStatus = user.status == 'locked' ? 'active' : 'locked';
    final action = nextStatus == 'locked' ? 'khóa' : 'mở khóa';
    if (!await _confirm(
      '${action[0].toUpperCase()}${action.substring(1)} tài khoản?',
      user.displayName,
    )) {
      return;
    }
    await _runMutation(
      () => _vm.setUserStatus(user, nextStatus),
      successMessage: 'Đã $action tài khoản.',
    );
  }

  Future<void> _reportAction(ReportModel report, String action) async {
    if (action == 'edit') {
      try {
        if (_vm.topics.isEmpty) await _vm.loadTopics();
        final question = await _vm.loadQuestion(report.questionId);
        if (!mounted) return;
        await _editQuestion(question: question);
        await _vm.loadReports();
      } catch (error) {
        if (mounted) _showMessage(error.toString());
      }
      return;
    }
    await _runMutation(
      () => _vm.setReportStatus(report, action),
      successMessage: 'Đã cập nhật trạng thái báo lỗi.',
    );
  }

  void _reportActions(ReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Sửa câu hỏi bị báo lỗi'),
              onTap: () {
                Navigator.pop(context);
                _reportAction(report, 'edit');
              },
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty),
              title: const Text('Chờ xử lý'),
              onTap: () {
                Navigator.pop(context);
                _reportAction(report, 'pending');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Đánh dấu đã xử lý'),
              onTap: () {
                Navigator.pop(context);
                _reportAction(report, 'resolved');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Từ chối báo lỗi'),
              onTap: () {
                Navigator.pop(context);
                _reportAction(report, 'rejected');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    Widget? header,
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
          ?header,
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
