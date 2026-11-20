import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../models/quiz_set_model.dart';
import '../../models/topic_model.dart';
import '../auth_quiz/quiz_set_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  String? _error;
  List<QuizSet> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ApiClient()
          .get('/favorites')
          .timeout(const Duration(seconds: 5));
      final list = (data as List? ?? [])
          .map((e) => QuizSet.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _favorites = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách yêu thích từ server';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeFavorite(QuizSet quizSet) async {
    final index = _favorites.indexWhere((e) => e.id == quizSet.id);
    if (index == -1) return;

    setState(() {
      _favorites.removeAt(index);
    });

    try {
      await ApiClient()
          .post('/favorites/${quizSet.id}/toggle', const {})
          .timeout(const Duration(seconds: 3));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã bỏ "${quizSet.title}" khỏi danh sách yêu thích'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _favorites.insert(index, quizSet);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể cập nhật, vui lòng thử lại')),
        );
      }
    }
  }

  String _levelLabel(String level) {
    switch (level.toLowerCase()) {
      case 'easy':
        return 'Dễ';
      case 'hard':
        return 'Khó';
      default:
        return 'Trung bình';
    }
  }

  Color _levelColor(String level) {
    switch (level.toLowerCase()) {
      case 'easy':
        return const Color(0xFF16A34A);
      case 'hard':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Yêu thích của tôi',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadFavorites,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _favorites.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadFavorites,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) {
                            return _buildQuizSetCard(_favorites[index]);
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💔', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Chưa có bộ đề yêu thích nào',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy bấm vào biểu tượng trái tim ở các bộ câu hỏi để lưu lại ôn tập nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizSetCard(QuizSet quizSet) {
    final badgeColor = _levelColor(quizSet.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizSetDetailScreen(
                quizSet: quizSet,
                topic: Topic(
                  id: quizSet.topicId,
                  name: 'Chủ đề đã lưu',
                  description: '',
                  icon: '📘',
                  questionCount: quizSet.questionCount,
                ),
              ),
            ),
          );
          _loadFavorites();
        },
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
                child: const Text('📘', style: TextStyle(fontSize: 22)),
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _levelLabel(quizSet.level),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        Text(
                          '• ${quizSet.questionCount} câu hỏi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '• ${(quizSet.durationSec / 60).ceil()} phút',
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
              IconButton(
                tooltip: 'Bỏ yêu thích',
                icon: const Icon(Icons.favorite, color: Color(0xFFEF4444)),
                onPressed: () => _removeFavorite(quizSet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}