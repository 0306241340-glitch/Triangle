import 'package:flutter/material.dart';

import '../../models/topic_model.dart';
import '../../viewmodels/home_profile_vm.dart';
import '../auth_quiz/quiz_set_detail_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';
import 'store_screen.dart';
import 'friends_screen.dart';
import '../../models/quiz_set_model.dart';
import '../../models/topic_model.dart';
import '../auth_quiz/quiz_set_detail_screen.dart';

import '../../viewmodels/home_profile_vm.dart';

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

  /// Khi bấm vào topic → lấy QuizSet đầu tiên đã tải từ API.
  /// Nếu topic chưa có bộ đề nào thì hiện SnackBar.
  Future<void> _openTopic(Topic topic) async {
    final sets = _vm.quizSetsForTopic(topic.id);
    if (sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chủ đề này chưa có bộ đề nào')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSetDetailScreen(quizSet: sets.first, topic: topic),
      ),
    );
    if (mounted) {
      _vm.load();
    }
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
                    if (_vm.topicFavoriteLoadError != null)
                      Card(
                        color: const Color(0xFFFFFBEB),
                        child: ListTile(
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD97706),
                          ),
                          title: const Text(
                            'Chưa tải được trạng thái yêu thích',
                          ),
                          subtitle: Text(_vm.topicFavoriteLoadError!),
                          trailing: IconButton(
                            tooltip: 'Thử lại',
                            onPressed: _vm.loadTopicFavorites,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
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
                                      IconButton(
                                        tooltip: _vm.isTopicFavorite(topic.id)
                                            ? 'Bỏ chủ đề yêu thích'
                                            : 'Lưu chủ đề yêu thích',
                                        visualDensity: VisualDensity.compact,
                                        onPressed:
                                            _vm.isUpdatingTopicFavorite(
                                              topic.id,
                                            )
                                            ? null
                                            : () async {
                                                final error = await _vm
                                                    .toggleTopicFavorite(
                                                      topic.id,
                                                    );
                                                if (error != null &&
                                                    context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Không thể cập nhật yêu thích: $error',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                        icon:
                                            _vm.isUpdatingTopicFavorite(
                                              topic.id,
                                            )
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                _vm.isTopicFavorite(topic.id)
                                                    ? Icons.favorite
                                                    : Icons.favorite_border,
                                                color:
                                                    _vm.isTopicFavorite(
                                                      topic.id,
                                                    )
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF64748B),
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
