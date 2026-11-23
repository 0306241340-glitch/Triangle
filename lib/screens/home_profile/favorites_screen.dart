import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/favorite_model.dart';
import '../../models/quiz_set_model.dart';
import '../../models/topic_model.dart';
import '../auth_quiz/quiz_set_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late final TabController _tabs;
  bool _isLoading = true;
  String? _error;
  String? _topicFavoritesError;
  List<FavoriteModel> _favorites = [];
  List<Topic> _topics = [];
  List<QuizSet> _quizSets = [];
  final Set<String> _removingIds = {};

  List<FavoriteModel> get _favoriteTopics =>
      _favorites.where((favorite) => favorite.targetType == 'topic').toList();

  List<FavoriteModel> get _favoriteQuizSets =>
      _favorites.where((favorite) => favorite.targetType == 'quizSet').toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _attachToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để xem danh sách yêu thích.');
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(token);
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _topicFavoritesError = null;
    });

    try {
      await _attachToken();
      final responses = await Future.wait([
        _api.get('/favorites'),
        _api.get('/topics'),
        _api.get('/quiz-sets'),
      ]);
      final favorites = <FavoriteModel>[];
      final topics = (responses[1] as List)
          .map((item) => Topic.fromJson(item as Map<String, dynamic>))
          .toList();
      final quizSets = (responses[2] as List)
          .map((item) => QuizSet.fromJson(item as Map<String, dynamic>))
          .toList();
      for (final rawItem in responses[0] as List) {
        final item = rawItem as Map<String, dynamic>;
        if (item.containsKey('targetId') || item.containsKey('target_id')) {
          favorites.add(FavoriteModel.fromJson(item));
        } else if (item.containsKey('topicId') && item.containsKey('id')) {
          final quizSet = QuizSet.fromJson(item);
          if (quizSet.id.isNotEmpty) {
            favorites.add(
              FavoriteModel(
                id: 'legacy-${quizSet.id}',
                targetId: quizSet.id,
                targetType: 'quizSet',
              ),
            );
            if (!quizSets.any((set) => set.id == quizSet.id)) {
              quizSets.add(quizSet);
            }
          }
        }
      }

      try {
        final topicStatuses = await Future.wait(
          topics.map(
            (topic) => _api.get(
              '/favorites/status',
              query: {'targetId': topic.id, 'targetType': 'topic'},
            ),
          ),
        );
        for (var index = 0; index < topics.length; index++) {
          final topic = topics[index];
          final isFavorite =
              (topicStatuses[index] as Map<String, dynamic>)['isFavorite'] ==
              true;
          if (isFavorite &&
              !favorites.any(
                (favorite) =>
                    favorite.targetType == 'topic' &&
                    favorite.targetId == topic.id,
              )) {
            favorites.add(
              FavoriteModel(
                id: 'topic-${topic.id}',
                targetId: topic.id,
                targetType: 'topic',
              ),
            );
          }
        }
      } catch (error) {
        _topicFavoritesError = error.toString();
      }

      if (!mounted) return;
      setState(() {
        _favorites = favorites;
        _topics = topics;
        _quizSets = quizSets;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(FavoriteModel favorite) async {
    if (_removingIds.contains(favorite.id)) return;
    setState(() => _removingIds.add(favorite.id));
    try {
      await _attachToken();
      await _api.delete(
        '/favorites',
        query: {
          'targetId': favorite.targetId,
          'targetType': favorite.targetType,
        },
      );
      if (!mounted) return;
      setState(
        () => _favorites.removeWhere((item) => item.id == favorite.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ mục khỏi danh sách yêu thích.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể bỏ yêu thích: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _removingIds.remove(favorite.id));
    }
  }

  Future<void> _openQuizSet(QuizSet quizSet) async {
    final topic = _topicFor(quizSet.topicId) ??
        Topic(
          id: quizSet.topicId,
          name: 'Chủ đề đã lưu',
          description: '',
          icon: '📘',
          questionCount: quizSet.questionCount,
        );
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => QuizSetDetailScreen(quizSet: quizSet, topic: topic),
      ),
    );
    if (mounted) _loadFavorites();
  }

  Future<void> _openTopic(Topic topic) async {
    final sets = _quizSets.where((set) => set.topicId == topic.id).toList();
    if (sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chủ đề này hiện chưa có bộ đề.')),
      );
      return;
    }

    final selectedSet = await showModalBottomSheet<QuizSet>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Bộ đề ${topic.name}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...sets.map(
              (set) => ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text(set.title),
                subtitle: Text('${set.questionCount} câu • ${set.levelLabel}'),
                onTap: () => Navigator.pop(context, set),
              ),
            ),
          ],
        ),
      ),
    );
    if (selectedSet != null && mounted) _openQuizSet(selectedSet);
  }

  Topic? _topicFor(String id) {
    for (final topic in _topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  QuizSet? _quizSetFor(String id) {
    for (final quizSet in _quizSets) {
      if (quizSet.id == id) return quizSet;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Yêu thích của tôi'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Chủ đề (${_favoriteTopics.length})'),
            Tab(text: 'Bộ đề (${_favoriteQuizSets.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
              : Column(
                  children: [
                    if (_topicFavoritesError != null)
                      Card(
                        color: const Color(0xFFFFFBEB),
                        child: ListTile(
                          leading: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD97706),
                          ),
                          title: const Text('Chưa tải được chủ đề yêu thích'),
                          subtitle: Text(_topicFavoritesError!),
                          trailing: IconButton(
                            tooltip: 'Thử lại',
                            onPressed: _loadFavorites,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        children: [
                          _buildFavoriteList(
                            _favoriteTopics,
                            emptyMessage: 'Bạn chưa lưu chủ đề nào.',
                            itemBuilder: _buildTopicFavorite,
                          ),
                          _buildFavoriteList(
                            _favoriteQuizSets,
                            emptyMessage: 'Bạn chưa lưu bộ đề nào.',
                            itemBuilder: _buildQuizSetFavorite,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Không thể tải danh sách yêu thích.\n$_error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _loadFavorites, child: const Text('Thử lại')),
        ],
      ),
    ),
  );

  Widget _buildFavoriteList(
    List<FavoriteModel> favorites, {
    required String emptyMessage,
    required Widget Function(FavoriteModel) itemBuilder,
  }) {
    if (favorites.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFavorites,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 140),
            const Icon(
              Icons.favorite_border,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                emptyMessage,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: favorites.length,
        itemBuilder: (context, index) => itemBuilder(favorites[index]),
      ),
    );
  }

  Widget _buildTopicFavorite(FavoriteModel favorite) {
    final topic = _topicFor(favorite.targetId);
    if (topic == null) return _buildUnavailableFavorite(favorite);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Text(topic.icon, style: const TextStyle(fontSize: 28)),
        title: Text(
          topic.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          topic.description.isEmpty
              ? '${topic.questionCount} câu hỏi'
              : '${topic.description}\n${topic.questionCount} câu hỏi',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _removeButton(favorite),
        onTap: () => _openTopic(topic),
      ),
    );
  }

  Widget _buildQuizSetFavorite(FavoriteModel favorite) {
    final quizSet = _quizSetFor(favorite.targetId);
    if (quizSet == null) return _buildUnavailableFavorite(favorite);
    final badgeColor = _levelColor(quizSet.level);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openQuizSet(quizSet),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.quiz_outlined, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quizSet.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (quizSet.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        quizSet.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _levelBadge(quizSet.levelLabel, badgeColor),
                        Text(
                          '${quizSet.questionCount} câu hỏi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '${(quizSet.durationSec / 60).ceil()} phút',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _removeButton(favorite),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableFavorite(FavoriteModel favorite) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: const Icon(Icons.bookmark_outline),
      title: Text(
        favorite.targetType == 'topic' ? 'Chủ đề không còn khả dụng' : 'Bộ đề không còn khả dụng',
      ),
      subtitle: Text(favorite.targetId),
      trailing: _removeButton(favorite),
    ),
  );

  Widget _removeButton(FavoriteModel favorite) {
    final isRemoving = _removingIds.contains(favorite.id);
    return IconButton(
      tooltip: 'Bỏ yêu thích',
      onPressed: isRemoving ? null : () => _removeFavorite(favorite),
      icon: isRemoving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.favorite, color: Color(0xFFEF4444)),
    );
  }

  Widget _levelBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'easy':
        return const Color(0xFF16A34A);
      case 'hard':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF4F46E5);
    }
  }
}
