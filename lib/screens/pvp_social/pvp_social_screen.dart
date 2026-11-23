import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/friend_model.dart';
import '../../models/notification_model.dart';
import '../../models/room_model.dart';
import '../../services/friend_service.dart';
import '../../services/pvp_social_service.dart';

class PvpSocialScreen extends StatefulWidget {
  const PvpSocialScreen({super.key, this.service, this.friendService});

  final PvpSocialService? service;
  final FriendService? friendService;

  @override
  State<PvpSocialScreen> createState() => _PvpSocialScreenState();
}

class _PvpSocialScreenState extends State<PvpSocialScreen>
    with SingleTickerProviderStateMixin {
  late final PvpSocialService _service;
  late final FriendService _friendService;
  late final TabController _tabController;
  late Future<List<FriendRequest>> _friendsFuture;
  late Future<List<PvpInvitation>> _invitationsFuture;
  final Map<String, Future<PublicProfile?>> _profileFutures = {};
  Timer? _invitationRefreshTimer;
  bool _searching = false;
  String? _actionId;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PvpSocialService();
    _friendService = widget.friendService ?? FriendService();
    _tabController = TabController(length: 3, vsync: this);
    _friendsFuture = _friendService.loadFriends();
    _invitationsFuture = _service.loadInvitations();
    _invitationRefreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshInvitations(),
    );
  }

  @override
  void dispose() {
    _invitationRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _refreshFriends() {
    setState(() => _friendsFuture = _friendService.loadFriends());
  }

  void _refreshInvitations() {
    if (mounted) {
      setState(() => _invitationsFuture = _service.loadInvitations());
    }
  }

  Future<PublicProfile?> _loadFriendProfile(String uid) {
    return _profileFutures.putIfAbsent(
      uid,
      () => _friendService.getPublicProfile(uid),
    );
  }

  Future<void> _findRandomOpponent() async {
    if (_searching) return;
    setState(() => _searching = true);
    try {
      var queue = await _service.joinQueue();
      while (mounted && _searching) {
        if (queue.roomId != null) {
          await _openRoom(queue.roomId!);
          break;
        }
        if (queue.status == 'cancelled') {
          throw StateError('Tìm trận đã bị hủy.');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || !_searching) break;
        queue = await _service.queueStatus();
      }
    } catch (error) {
      if (mounted && _searching) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _cancelSearch() async {
    setState(() => _searching = false);
    try {
      await _service.leaveQueue();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _sendChallenge(String friendUid) async {
    setState(() => _actionId = friendUid);
    try {
      await _service.inviteFriend(friendUid);
      if (mounted) _showMessage('Đã gửi lời mời thách đấu.');
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  Future<void> _respondToInvitation(
    PvpInvitation invitation, {
    required bool accept,
  }) async {
    setState(() => _actionId = invitation.roomId);
    try {
      if (accept) {
        await _service.acceptInvitation(invitation.roomId);
        await _openRoom(invitation.roomId);
      } else {
        await _service.declineInvitation(invitation.roomId);
        if (mounted) _showMessage('Đã từ chối lời mời.');
      }
      _refreshInvitations();
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _actionId = null);
    }
  }

  Future<void> _openRoom(String roomId) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PvpRoomScreen(roomId: roomId, service: _service),
      ),
    );
    if (mounted) _refreshInvitations();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Đấu 1vs1'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () {
              _refreshFriends();
              _refreshInvitations();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Đấu nhanh'),
            Tab(text: 'Thách bạn'),
            Tab(text: 'Lời mời'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickMatchTab(),
          _buildFriendsTab(),
          _buildInvitationsTab(),
        ],
      ),
    );
  }

  Widget _buildQuickMatchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sports_martial_arts, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Tìm đối thủ ngẫu nhiên',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('10 câu hỏi · 15 giây mỗi câu · đúng được 10 điểm'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _searching ? _cancelSearch : _findRandomOpponent,
                    icon: Icon(_searching ? Icons.close : Icons.search),
                    label: Text(_searching ? 'Hủy tìm trận' : 'Tìm trận ngay'),
                  ),
                ),
                if (_searching) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Đang tìm người chơi phù hợp...'),
                ],
              ],
            ),
          ),
        ),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Mỗi câu chỉ gửi một lần. Nếu hết 15 giây, câu hỏi sẽ tự chuyển '
              'và câu chưa trả lời không được tính điểm.',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    return FutureBuilder<List<FriendRequest>>(
      future: _friendsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState(
            'Không tải được danh sách bạn bè.',
            _refreshFriends,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final friends = snapshot.data!;
        if (friends.isEmpty) {
          return const Center(child: Text('Bạn chưa có bạn bè để thách đấu.'));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: friends.map((friend) {
            final uid = friend.otherUserId(_friendService.currentUserId);
            return FutureBuilder<PublicProfile?>(
              future: _loadFriendProfile(uid),
              builder: (context, profileSnapshot) {
                final profile = profileSnapshot.data;
                final displayName = profile?.displayName ?? 'Người chơi';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName.characters.first
                            : '?',
                      ),
                    ),
                    title: Text(displayName),
                    subtitle: profileSnapshot.hasError
                        ? const Text('Không tải được hồ sơ bạn bè')
                        : null,
                    trailing: IconButton(
                      tooltip: 'Thách đấu',
                      onPressed:
                          profileSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              _actionId == uid
                          ? null
                          : () => _sendChallenge(uid),
                      icon: _actionId == uid
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sports_kabaddi),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInvitationsTab() {
    return FutureBuilder<List<PvpInvitation>>(
      future: _invitationsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState(
            'Không tải được lời mời thách đấu.',
            _refreshInvitations,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final invitations = snapshot.data!;
        if (invitations.isEmpty) {
          return const Center(child: Text('Chưa có lời mời thách đấu nào.'));
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: invitations.map((invitation) {
            final busy = _actionId == invitation.roomId;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.sports_kabaddi)),
                title: Text('${invitation.hostName} thách đấu bạn'),
                subtitle: const Text('10 câu · 15 giây mỗi câu'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Chấp nhận',
                      onPressed: busy
                          ? null
                          : () =>
                                _respondToInvitation(invitation, accept: true),
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                    IconButton(
                      tooltip: 'Từ chối',
                      onPressed: busy
                          ? null
                          : () =>
                                _respondToInvitation(invitation, accept: false),
                      icon: const Icon(Icons.cancel_outlined),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _errorState(String message, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: retry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class PvpRoomScreen extends StatefulWidget {
  const PvpRoomScreen({required this.roomId, required this.service, super.key});

  final String roomId;
  final PvpSocialService service;

  @override
  State<PvpRoomScreen> createState() => _PvpRoomScreenState();
}

class _PvpRoomScreenState extends State<PvpRoomScreen> {
  PvpRoom? _room;
  Timer? _refreshTimer;
  bool _loading = true;
  bool _polling = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshRoom();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshRoom(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshRoom() async {
    if (_polling) return;
    _polling = true;
    try {
      final room = await widget.service.loadRoom(widget.roomId);
      if (!mounted) return;
      setState(() {
        _room = room;
        _error = null;
        _loading = false;
      });
      if (room.status == 'finished' || room.status == 'cancelled') {
        _refreshTimer?.cancel();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _answer(int selectedIndex) async {
    final room = _room;
    if (room == null ||
        room.question == null ||
        room.myAnswered ||
        _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final updated = await widget.service.submitAnswer(
        roomId: room.id,
        questionIndex: room.questionIndex,
        selectedIndex: selectedIndex,
      );
      if (mounted) setState(() => _room = updated);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
        await _refreshRoom();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Scaffold(
      appBar: AppBar(title: const Text('Trận đấu 1vs1')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : room == null
          ? _buildLoadError()
          : _buildRoom(room),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Không tải được trận đấu.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refreshRoom, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _buildRoom(PvpRoom room) {
    if (room.status == 'finished' || room.status == 'cancelled') {
      return _buildResult(room);
    }
    if (room.status == 'waiting') {
      return const Center(child: Text('Đang chờ bạn chấp nhận lời mời...'));
    }
    final question = room.question;
    if (question == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final currentUid = widget.service.currentUserId;
    final myScore = currentUid == room.hostId
        ? room.hostScore
        : room.guestScore;
    final opponentScore = currentUid == room.hostId
        ? room.guestScore
        : room.hostScore;
    final remaining = _secondsRemaining(room);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _scoreCard(room.hostName, room.hostScore)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(child: _scoreCard(room.guestName, room.guestScore)),
          ],
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: room.questionCount == 0
              ? 0
              : (room.questionIndex + 1) / room.questionCount,
        ),
        const SizedBox(height: 8),
        Text(
          'Câu ${room.questionIndex + 1}/${room.questionCount}  ·  '
          'Còn $remaining giây',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              question.content,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...question.options.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: room.myAnswered || _submitting
                  ? null
                  : () => _answer(entry.key),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(14),
                alignment: Alignment.centerLeft,
              ),
              child: Text(entry.value),
            ),
          );
        }),
        if (room.myAnswered) ...[
          const SizedBox(height: 8),
          Text(
            room.opponentAnswered
                ? 'Đang chuyển câu...'
                : 'Đã gửi đáp án. Đang chờ đối thủ...',
            textAlign: TextAlign.center,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            'Mất kết nối tạm thời, đang thử lại: $_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'Điểm của bạn: $myScore  ·  Đối thủ: $opponentScore',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _scoreCard(String name, int score) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              '$score điểm',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  int _secondsRemaining(PvpRoom room) {
    final startedAt = room.questionStartTime;
    if (startedAt == null) return room.questionSeconds;
    final elapsed = DateTime.now().toUtc().difference(startedAt).inSeconds;
    return (room.questionSeconds - elapsed).clamp(0, room.questionSeconds);
  }

  Widget _buildResult(PvpRoom room) {
    final currentUid = widget.service.currentUserId;
    final isDraw = room.winnerId == null;
    final didWin = room.winnerId == currentUid;
    final title = room.status == 'cancelled'
        ? 'Trận đấu đã bị hủy'
        : isDraw
        ? 'Trận đấu hòa!'
        : didWin
        ? 'Bạn đã chiến thắng!'
        : 'Đối thủ chiến thắng';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${room.hostName} ${room.hostScore} - ${room.guestScore} '
              '${room.guestName}',
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}
