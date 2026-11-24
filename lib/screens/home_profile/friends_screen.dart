import 'package:flutter/material.dart';

import '../../models/friend_model.dart';
import '../../services/friend_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.service});

  final FriendService? service;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final FriendService _service;
  late final TabController _tabController;
  final _searchController = TextEditingController();
  Future<List<PublicProfile>>? _searchFuture;
  String? _actionId;
  String? _initializationError;
  late final Future<void> _profileReady;
  late Future<List<FriendRequest>> _friendsFuture;
  late Future<List<FriendRequest>> _incomingFuture;
  late Future<List<FriendRequest>> _outgoingFuture;
  final Map<String, Future<PublicProfile?>> _profileFutures = {};

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FriendService();
    _tabController = TabController(length: 3, vsync: this);
    _profileReady = _initializeProfile();
    _friendsFuture = _service.loadFriends();
    _incomingFuture = _service.loadRequests(incoming: true);
    _outgoingFuture = _service.loadRequests(incoming: false);
  }

  void _refreshRelations() {
    setState(() {
      _friendsFuture = _service.loadFriends();
      _incomingFuture = _service.loadRequests(incoming: true);
      _outgoingFuture = _service.loadRequests(incoming: false);
    });
  }

  Future<void> _initializeProfile() async {
    try {
      await _service.ensurePublicProfile();
    } catch (error) {
      _initializationError = error.toString();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập ít nhất 2 ký tự để tìm kiếm.')),
      );
      return;
    }
    setState(() {
      _searchFuture = _service.searchUsers(query);
    });
  }

  Future<void> _runAction(
    String id,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _actionId = id);
    try {
      await action();
      if (!mounted) return;
      _refreshRelations();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Bạn bè'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _refreshRelations,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bạn bè'),
            Tab(text: 'Lời mời'),
            Tab(text: 'Tìm bạn'),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _profileReady,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_initializationError != null) {
            return _buildError(_initializationError!);
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsTab(),
              _buildRequestsTab(),
              _buildSearchTab(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(error, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return FutureBuilder<List<FriendRequest>>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError('Không tải được danh sách bạn bè.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('Bạn chưa có bạn bè nào.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: requests.map((request) {
            final uid = request.otherUserId(_service.currentUserId);
            return _profileTile(
              uid,
              trailing: TextButton(
                onPressed: _actionId == request.id
                    ? null
                    : () => _runAction(
                        request.id,
                        () => _service.removeFriend(request.id),
                        successMessage: 'Đã xóa bạn bè.',
                      ),
                child: const Text('Xóa'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Lời mời đã nhận',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _requestList(future: _incomingFuture, incoming: true),
        const SizedBox(height: 20),
        const Text(
          'Lời mời đã gửi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _requestList(future: _outgoingFuture, incoming: false),
      ],
    );
  }

  Widget _requestList({
    required Future<List<FriendRequest>> future,
    required bool incoming,
  }) {
    return FutureBuilder<List<FriendRequest>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Không tải được lời mời kết bạn.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return Text(
            incoming ? 'Chưa có lời mời mới.' : 'Chưa gửi lời mời nào.',
          );
        }

        return Column(
          children: snapshot.data!.map((request) {
            final uid = request.otherUserId(_service.currentUserId);
            return _profileTile(
              uid,
              trailing: incoming
                  ? Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Chấp nhận',
                          onPressed: _actionId == request.id
                              ? null
                              : () => _runAction(
                                  request.id,
                                  () => _service.acceptRequest(request.id),
                                  successMessage: 'Đã chấp nhận lời mời.',
                                ),
                          icon: const Icon(Icons.check_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Từ chối',
                          onPressed: _actionId == request.id
                              ? null
                              : () => _runAction(
                                  request.id,
                                  () => _service.rejectRequest(request.id),
                                  successMessage: 'Đã từ chối lời mời.',
                                ),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    )
                  : TextButton(
                      onPressed: _actionId == request.id
                          ? null
                          : () => _runAction(
                              request.id,
                              () => _service.cancelRequest(request.id),
                              successMessage: 'Đã thu hồi lời mời.',
                            ),
                      child: const Text('Thu hồi'),
                    ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _profileTile(String uid, {required Widget trailing}) {
    return FutureBuilder<PublicProfile?>(
      future: _profileFutures.putIfAbsent(
        uid,
        () => _service.getPublicProfile(uid),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ListTile(title: Text('Không tải được hồ sơ.'));
        }
        final profile = snapshot.data;
        if (profile == null) {
          return ListTile(
            title: Text(
              snapshot.connectionState == ConnectionState.waiting
                  ? 'Đang tải hồ sơ...'
                  : 'Không tìm thấy hồ sơ người chơi.',
            ),
          );
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: profile.avatarUrl.isNotEmpty
                  ? NetworkImage(profile.avatarUrl)
                  : null,
              child: profile.avatarUrl.isEmpty
                  ? Text(_initials(profile.displayName))
                  : null,
            ),
            title: Text(profile.displayName),
            subtitle: Text('Mã kết bạn: ${profile.userCode}'),
            trailing: trailing,
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Tìm theo mã hoặc tên',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Tìm kiếm',
              onPressed: _search,
              icon: const Icon(Icons.arrow_forward),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<PublicProfile>>(
          future: _searchFuture,
          builder: (context, snapshot) {
            if (_searchFuture == null) {
              return const Text('Nhập mã kết bạn hoặc tên để tìm người chơi.');
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Tìm kiếm thất bại: ${snapshot.error}');
            }
            final profiles = snapshot.data ?? [];
            if (profiles.isEmpty) {
              return const Text('Không tìm thấy người chơi.');
            }
            return Column(
              children: profiles.map((profile) {
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(_initials(profile.displayName)),
                    ),
                    title: Text(profile.displayName),
                    subtitle: Text('Mã kết bạn: ${profile.userCode}'),
                    trailing: FilledButton(
                      onPressed: _actionId == profile.uid
                          ? null
                          : () => _runAction(
                              profile.uid,
                              () => _service.sendRequest(profile.uid),
                              successMessage: 'Đã gửi lời mời kết bạn.',
                            ),
                      child: const Text('Kết bạn'),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return 'U';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}
