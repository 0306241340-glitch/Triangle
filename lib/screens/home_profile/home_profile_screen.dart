// Màn Trang chủ (S05) — TV1 An giữ, thẻ [Mục 9-11] một mình An làm.
// Theo đúng wireframe đã vẽ trên Figma: chào user, điểm/xu, tìm kiếm,
// thẻ Đấu 1vs1, danh sách chủ đề, BottomNav 4 tab.
// Chạy được ngay bằng dữ liệu mẫu, chưa cần Firebase (xem HomeViewModel).
import 'package:flutter/material.dart';

import '../../viewmodels/home_profile_vm.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _vm;

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
                      onChanged: _vm.setQuery,
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
                            const Text('⚔️ Đấu 1vs1',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const Text(
                                'Thách đấu bạn bè, 10 câu – 15 giây/câu'),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                // TODO: mở phòng đấu 1vs1 (S15) khi Vương làm xong màn đó
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Phòng đấu 1vs1 — đang làm ở tuần 2')),
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
                    const Text('Chủ đề',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._vm.filteredTopics.map((topic) => Card(
                          child: ListTile(
                            leading: Text(topic.icon,
                                style: const TextStyle(fontSize: 28)),
                            title: Text(topic.name),
                            subtitle: Text(topic.description),
                            trailing: Text('${topic.questionCount} câu'),
                            // TODO: bấm vào mở Danh sách bộ đề S06 (commit sau)
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Mở danh sách bộ đề: ${topic.name} (S06 — commit sau)')),
                              );
                            },
                          ),
                        )),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            child: const Text('🛒 Cửa hàng'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
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
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
              BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Xếp hạng'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch sử'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Hồ sơ'),
            ],
            // TODO: chuyển tab khi các màn S18/S19/S10 xong (Ngọc, Vương, TV4)
            onTap: (i) {
              if (i != 0) {
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
