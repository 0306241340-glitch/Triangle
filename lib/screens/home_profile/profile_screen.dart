import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/user_model.dart';
import 'edit_profile_screen.dart';
import 'inventory_screen.dart';
import 'friends_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>>? _profileFuture;
  String? _profileUid;

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _handleSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  Future<Map<String, dynamic>> _loadProfile(User user) async {
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    final api = ApiClient()..setToken(token);
    return await api.get('/me') as Map<String, dynamic>;
  }

  void _reloadProfile(User user) {
    setState(() {
      _profileUid = user.uid;
      _profileFuture = _loadProfile(user);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));
    }
    if (_profileUid != user.uid || _profileFuture == null) {
      _profileUid = user.uid;
      _profileFuture = _loadProfile(user);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Hồ sơ',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Không thể tải hồ sơ người dùng: ${snapshot.error}',
                ),
              );
            }

            final data = snapshot.data ?? <String, dynamic>{};
            final profile = UserModel.fromMap(data, user.uid);
            final initials = _getInitials(profile.displayName);

            final equippedFrameId = profile.frameId;
            final titleName = profile.titleName;
            final frameName = profile.frameName;
            final hasFrame = equippedFrameId?.isNotEmpty == true;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Center(
                  child: _buildAvatarWithFrame(
                    avatarUrl: profile.avatarUrl,
                    initials: initials,
                    hasFrame: hasFrame,
                    frameId: equippedFrameId,
                    frameName: frameName,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (titleName != null && titleName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Center(child: _buildTitleBadge(titleName)),
                ],
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Mã kết bạn: ${profile.userCode}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('${profile.score}', 'điểm')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatCard('${profile.coins}', 'xu')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        '${profile.gamesPlayed}',
                        'lượt chơi',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  icon: '✏️',
                  title: 'Sửa hồ sơ',
                  subtitle: 'Tên, avatar, đổi mật khẩu',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(userModel: profile),
                      ),
                    ).then((_) => _reloadProfile(user));
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: '🎒',
                  title: 'Túi đồ',
                  subtitle: 'Quản lý quyền trợ giúp, khung avatar & danh hiệu',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(),
                      ),
                    ).then((_) => _reloadProfile(user));
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: '❤️',
                  title: 'Yêu thích của tôi',
                  subtitle: '3 bộ đề • 2 chủ đề',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mở danh sách Yêu thích')),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: '👥',
                  title: 'Bạn bè',
                  subtitle: 'Quản lý danh sách & lời mời kết bạn',
                  isHighlighted: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FriendsScreen()),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => _handleSignOut(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvatarWithFrame({
    required String? avatarUrl,
    required String initials,
    required bool hasFrame,
    String? frameId,
    String? frameName,
  }) {
    Color borderColor = const Color(0xFF2563EB);
    double borderWidth = 1.5;
    List<BoxShadow>? shadows;

    if (hasFrame) {
      borderWidth = 4.0;
      final lowerName = '${frameId ?? ''} ${frameName ?? ''}'.toLowerCase();
      if (lowerName.contains('gold') || lowerName.contains('vàng')) {
        borderColor = const Color(0xFFF59E0B);
        shadows = [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.45),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ];
      } else if (lowerName.contains('diamond') ||
          lowerName.contains('kim cương')) {
        borderColor = const Color(0xFF06B6D4);
        shadows = [
          BoxShadow(
            color: const Color(0xFF06B6D4).withOpacity(0.45),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ];
      } else {
        borderColor = const Color(0xFF7C3AED);
        shadows = [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ];
      }
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: hasFrame ? 82 : 72,
          height: hasFrame ? 82 : 72,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          alignment: Alignment.center,
          child: avatarUrl?.trim().isNotEmpty == true
              ? ClipOval(
                  child: avatarUrl!.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(avatarUrl.split(',').last),
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildInitials(initials),
                        )
                      : Image.network(
                          avatarUrl,
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildInitials(initials),
                        ),
                )
              : _buildInitials(initials),
        ),
        if (hasFrame)
          Positioned(
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Text(
                '👑',
                style: TextStyle(fontSize: 10, height: 1.1),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleBadge(String titleName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎓', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            titleName,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3730A3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String initials) {
    return Text(
      initials,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1D4ED8),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHighlighted ? const Color(0xFF2563EB) : Colors.grey.shade300,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
