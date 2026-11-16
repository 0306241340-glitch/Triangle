import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dart:convert';

import 'edit_profile_screen.dart';
import '../../models/user_model.dart';
import 'inventory_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  ImageProvider? _resolveAvatarImage(String? avatarStr) {
    if (avatarStr == null || avatarStr.isEmpty) return null;
    if (avatarStr.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(avatarStr.split(',').last));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(avatarStr);
  }

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));
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
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text('Không thể tải hồ sơ người dùng'),
              );
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final profile = UserModel.fromMap({
              ...data,
              'email': data['email'] ?? user.email ?? '',
              'displayName': data['displayName'] ?? user.displayName ?? '',
            }, user.uid);
            final initials = _getInitials(profile.displayName);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: profile.avatarUrl?.trim().isNotEmpty == true
                        ? ClipOval(
                            child: profile.avatarUrl!.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(
                                      profile.avatarUrl!.split(',').last,
                                    ),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) => _buildInitials(initials),
                                  )
                                : Image.network(
                                    profile.avatarUrl!,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      context,
                                      error,
                                      stackTrace,
                                    ) => _buildInitials(initials),
                                  ),
                          )
                        : _buildInitials(initials),
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
                const SizedBox(height: 4),
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
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  icon: '🎒',
                  title: 'Túi đồ',
                  subtitle: '50/50 x2 • Thêm thời gian x1 • Khung Vàng',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(),
                      ),
                    );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mở danh sách Bạn bè')),
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
