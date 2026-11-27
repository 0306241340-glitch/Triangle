import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/quiz_set_model.dart';
import '../../models/topic_model.dart';
import '../../viewmodels/home_profile_vm.dart';
import '../auth_quiz/quiz_set_detail_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../pvp_social/pvp_social_screen.dart';
import 'friends_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.vm});

  final HomeViewModel? vm;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = widget.vm ?? HomeViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.vm == null) {
      _vm.dispose();
    }
    super.dispose();
  }

  /// Khi bấm vào topic:
  /// - Chưa có bộ đề nào → hiện SnackBar.
  /// - Chỉ có 1 bộ đề → vào thẳng màn chi tiết.
  /// - Có nhiều bộ đề → hiện danh sách để người chơi chọn bộ.
  Future<void> _openTopic(Topic topic) async {
    final sets = _vm.quizSetsForTopic(topic.id);
    if (sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chủ đề này chưa có bộ đề nào')),
      );
      return;
    }
    QuizSet? selected = sets.first;
    if (sets.length > 1) {
      selected = await _pickQuizSet(topic, sets);
      if (selected == null || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSetDetailScreen(quizSet: selected!, topic: topic),
      ),
    );
    if (mounted) {
      _vm.load();
    }
  }

  Future<QuizSet?> _pickQuizSet(Topic topic, List<QuizSet> sets) {
    return showModalBottomSheet<QuizSet>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                'Chọn bộ đề — ${topic.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sets.length} bộ đề có sẵn',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              for (final set in sets)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.levelColor(set.level)
                          .withValues(alpha: 0.15),
                      child: Icon(
                        Icons.quiz_outlined,
                        color: AppColors.levelColor(set.level),
                      ),
                    ),
                    title: Text(
                      set.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${set.levelLabel} • ${set.questionCount} câu • '
                      '${set.durationSec ~/ 60} phút • ${set.attemptCount} lượt',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(sheetContext, set),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        final topics = _vm.filteredTopics;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text('Xin chào, ${_vm.displayName}'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('⭐ ${_vm.userScore}đ · 🪙 ${_vm.userCoins} xu'),
                ),
              ),
            ],
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _vm.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Không thể tải dữ liệu từ máy chủ.\n${_vm.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _vm.load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      onChanged: (value) => _vm.setQuery(value),
                      decoration: InputDecoration(
                        hintText: 'Tìm chủ đề, bộ đề...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚔️ Đấu 1vs1',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'Thách đấu bạn bè, 10 câu – 15 giây/câu',
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PvpSocialScreen(),
                                  ),
                                ),
                                child: const Text('Tìm trận ngay'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chủ đề',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (topics.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Không tìm thấy chủ đề nào'),
                        ),
                      )
                    else
                      ...topics.map(
                        (topic) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          elevation: 0,
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _openTopic(topic),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${topic.icon}  ${topic.name}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    topic.description,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoreScreen(homeVm: _vm),
                                ),
                              );
                            },
                            child: const Text('🛒 Cửa hàng'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FriendsScreen(),
                                ),
                              );
                            },
                            child: const Text('👥 Bạn bè'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF2563EB),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Trang chủ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events),
                label: 'Xếp hạng',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Lịch sử',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hồ sơ'),
            ],
            onTap: (i) {
              if (i == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                );
              } else if (i == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (i == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryScreen(homeViewModel: _vm),
                  ),
                );
              } else if (i != 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Màn này đang làm ở tuần 2')),
                );
              }
            },
          ),
        );
      },
    );
  }
}
