import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/leaderboard_model.dart';
import '../../viewmodels/leaderboard_vm.dart';

// Màn S18: BXH Toàn bộ / Tuần / Tháng / Bạn bè (mục 30, FR41) — v3.
// Màu sắc dùng đúng AppColors (mục 4.1 đã chốt): primary #1E3A8A,
// primaryLight #4F46E5, accent vàng hổ phách #F59E0B, nền #F8FAFC.
// - Header gradient primary -> primaryLight + bục Top 3 có khung
//   avatar vàng/bạc/đồng.
// - Danh sách trong thẻ trắng bo tròn, dòng của mình có nhãn "Bạn".
// - Thanh ghim "Hạng của bạn" gradient ở đáy màn hình.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

const _scopes = [
  ('all', 'Tất cả'),
  ('week', 'Tuần'),
  ('month', 'Tháng'),
  ('friends', 'Bạn bè'),
];

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = LeaderboardViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Bảng xếp hạng',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -30,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: 30,
              bottom: -70,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          return RefreshIndicator(
            onRefresh: () => _vm.load(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Wrap(
                    spacing: 8,
                    children: _scopes.map((s) {
                      final selected = _vm.scope == s.$1;
                      return ChoiceChip(
                        label: Text(s.$2),
                        selected: selected,
                        onSelected: _vm.isLoading
                            ? null
                            : (_) => _vm.load(s.$1),
                        selectedColor: primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected ? primary : Colors.grey.shade300,
                        ),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_vm.isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 8),
                if (_vm.entries.isNotEmpty)
                  _Podium(entries: _vm.entries.take(3).toList()),
                if (_vm.entries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _vm.entries.length; i++) ...[
                          _RankTile(
                            entry: _vm.entries[i],
                            isMe:
                                _vm.entries[i].uid.isNotEmpty &&
                                _vm.entries[i].uid == _vm.myUid,
                          ),
                          if (i < _vm.entries.length - 1)
                            const Divider(height: 1, indent: 72, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_vm.entries.isEmpty && !_vm.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(child: Text('Chưa có ai lên bảng')),
                  ),
                if (_vm.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _vm.error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) {
          if (_vm.myRank == null) return const SizedBox.shrink();
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: Text(
                      '${_vm.myRank}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Hạng của bạn',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Text(
                    '${_vm.myScore} điểm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final first = entries[0];
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: second == null
                ? const SizedBox()
                : _PodiumPlace(entry: second, rank: 2, barHeight: 64),
          ),
          Expanded(child: _PodiumPlace(entry: first, rank: 1, barHeight: 104)),
          Expanded(
            child: third == null
                ? const SizedBox()
                : _PodiumPlace(entry: third, rank: 3, barHeight: 80),
          ),
        ],
      ),
    );
  }
}

class _PodiumPlace extends StatelessWidget {
  const _PodiumPlace({
    required this.entry,
    required this.rank,
    required this.barHeight,
  });

  final LeaderboardEntry entry;
  final int rank;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1;
    final ringColor = switch (rank) {
      1 => AppColors.accent,
      2 => const Color(0xFF9CA3AF),
      _ => AppColors.accentDark,
    };
    final barColors = switch (rank) {
      1 => [AppColors.accent, AppColors.accentDark],
      2 => [const Color(0xFFE5E7EB), const Color(0xFF9CA3AF)],
      _ => [AppColors.accent.withValues(alpha: 0.5), AppColors.accentDark],
    };
    final rankTextColor = switch (rank) {
      1 => AppColors.accentDark,
      2 => const Color(0xFF4B5563),
      _ => AppColors.accentDark,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          const Icon(Icons.emoji_events, color: AppColors.accent, size: 30),
        if (isFirst) const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor,
            boxShadow: [
              BoxShadow(
                color: ringColor.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: _Avatar(entry: entry, radius: isFirst ? 32 : 26),
        ),
        const SizedBox(height: 8),
        Text(
          entry.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.score} điểm',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isFirst ? AppColors.accentDark : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: barHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: barColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: rankTextColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.radius});

  final LeaderboardEntry entry;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = entry.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isNotEmpty
          ? null
          : Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final medal = switch (entry.rank) {
      1 => AppColors.accent,
      2 => const Color(0xFF9CA3AF),
      3 => AppColors.accentDark,
      _ => null,
    };
    final tile = ListTile(
      leading: _Avatar(entry: entry, radius: 22),
      title: Row(
        children: [
          Flexible(
            child: Text(
              entry.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (isMe)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Bạn',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: entry.plays > 0
          ? Text(
              '${entry.plays} lượt thi',
              style: const TextStyle(color: AppColors.textSecondary),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (medal != null)
            CircleAvatar(
              radius: 13,
              backgroundColor: medal,
              child: Text(
                '${entry.rank}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (medal != null) const SizedBox(width: 8),
          Text(
            '${entry.score} điểm',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
    if (!isMe) return tile;
    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: tile,
    );
  }
}
