import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'store_screen.dart';
import 'friends_screen.dart';

import '../../viewmodels/home_profile_vm.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _vm;
  String _searchQuery = '';

  // 3 chủ đề đúng theo Wireframe (S05)
  static const _wireframeTopics = [
    {
      'title': 'Kiến thức tổng hợp / Đời sống',
      'description':
          'Các câu hỏi xoay quanh sự vật, hiện tượng tự nhiên, khoa học thường thức và xã hội.',
    },
    {
      'title': 'Đố dân gian & Câu đố mẹo',
      'description':
          'Các câu đố chữ, câu đố mẹo thử thách tư duy nhanh nhạy, chơi chữ và hài hước.',
    },
    {
      'title': 'Giải trí – Âm nhạc – Phim ảnh:',
      'description':
          'Kiến thức về các bộ phim nổi tiếng, ca sĩ, diễn viên, bài hát hoặc các chương trình truyền hình.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _vm = HomeViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTopics = _wireframeTopics.where((topic) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return topic['title']!.toLowerCase().contains(q) ||
          topic['description']!.toLowerCase().contains(q);
    }).toList();

    return AnimatedBuilder(
      animation: _vm,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Xin chào, An'),
            actions: const [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(child: Text('⭐ 180đ · 🪙 190 xu')),
              ),
            ],
          ),
          body: _vm.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _vm.setQuery(value);
                      },
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
                                // TODO: mở phòng đấu 1vs1 (S15) khi Vương làm xong màn đó
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Phòng đấu 1vs1 — đang làm ở tuần 2',
                                      ),
                                    ),
                                  );
                                },
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
                    ...filteredTopics.map(
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
                          // TODO: bấm vào mở Danh sách bộ đề S06 (commit sau)
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Mở danh sách bộ đề: ${topic['title']} (S06 — commit sau)',
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  topic['title']!,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  topic['description']!,
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
                                  builder: (_) => const StoreScreen(),
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
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Hồ sơ',
              ),
            ],
            onTap: (i) {
              if (i == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
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
