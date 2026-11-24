import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/leaderboard_model.dart';
import '../../viewmodels/leaderboard_vm.dart';

// Màn A07: Admin thống kê (mục 8, FR39). Chỉ tài khoản role=admin
// mới xem được, còn lại API trả 403 (VM đã đổi thành câu
// "Chỉ quản trị viên mới xem được mục này").
// Màu sắc dùng đúng AppColors (mục 4.1 đã chốt) như màn BXH v3
// đã push lên dev: primary #1E3A8A, primaryLight #4F46E5,
// accent vàng hổ phách #F59E0B, nền #F8FAFC — không ghi mã màu lẻ.
// Chỉ 1 file mới: lib/screens/admin/admin_stats_screen.dart.
// Model AdminStats + AdminStatsViewModel đã có sẵn trong
// leaderboard_model.dart / leaderboard_vm.dart trên dev, khớp đúng
// JSON GET /admin/stats (totals, byQuizSet, byTopic,
// mostReportedQuestions, recentAttempts).
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late final AdminStatsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = AdminStatsViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Thống kê',
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
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.isLoading && _vm.stats == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_vm.error != null && _vm.stats == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_vm.error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _vm.load,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          final s = _vm.stats!;
          return RefreshIndicator(
            onRefresh: _vm.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _TotalCard(
                      label: 'Người dùng',
                      value: s.users,
                      icon: Icons.people,
                    ),
                    _TotalCard(
                      label: 'Bộ đề',
                      value: s.quizSets,
                      icon: Icons.library_books,
                    ),
                    _TotalCard(
                      label: 'Câu hỏi',
                      value: s.questions,
                      icon: Icons.question_answer,
                    ),
                    _TotalCard(
                      label: 'Lượt thi',
                      value: s.attempts,
                      icon: Icons.play_circle_filled,
                    ),
                  ],
                ),
                if (s.pendingReports > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Chip(
                      avatar: const Icon(
                        Icons.flag,
                        color: AppColors.accentDark,
                        size: 18,
                      ),
                      label: Text(
                        '${s.pendingReports} báo lỗi chờ xử lý',
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
                  children: s.byQuizSet.map(
                    (q) => ListTile(
                      title: Text(
                        q.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${q.attempts} lượt thi • TB ${q.avgScore} • Cao nhất ${q.maxScore}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Điểm theo chủ đề',
                  children: s.byTopic.map(
                    (t) => ListTile(
                      title: Text(
                        t.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${t.attempts} lượt thi • TB ${t.avgScore}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Câu bị báo lỗi nhiều nhất',
                  children: s.mostReported.map(
                    (r) => ListTile(
                      title: Text(
                        r.content.isEmpty ? r.questionId : r.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      trailing: Text(
                        '${r.count} báo lỗi',
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
                  children: s.recentAttempts.map(
                    (a) => ListTile(
                      title: Text(
                        a.displayName.isEmpty ? 'Người chơi' : a.displayName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        a.quizSetName,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: Text(
                        '${a.score} điểm',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
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
