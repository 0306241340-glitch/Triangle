import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/quiz_set_model.dart';
import '../../models/review_model.dart';
import '../../models/topic_model.dart';
import 'quiz_play_screen.dart';

class QuizSetDetailScreen extends StatefulWidget {
  const QuizSetDetailScreen({
    super.key,
    required this.quizSet,
    required this.topic,
  });

  final QuizSet quizSet;
  final Topic topic;

  @override
  State<QuizSetDetailScreen> createState() => _QuizSetDetailScreenState();
}

class _QuizSetDetailScreenState extends State<QuizSetDetailScreen> {
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  String? _loadError;
  late QuizSet _set;
  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _set = widget.quizSet;
    _loadRealSet();
    _loadFavorite();
  }

  Future<void> _attachToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Bạn cần đăng nhập.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Phiên đăng nhập hết hạn.');
    }
    ApiClient().setToken(token);
  }

  Future<void> _loadRealSet() async {
    try {
      await _attachToken();
      final m = await ApiClient().get(
        '/quiz-sets/${widget.quizSet.id}',
      ) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _set = QuizSet.fromJson(m);
        _reviews = (m['comments'] as List? ?? []).map((e) {
          return Review.fromJson(e as Map<String, dynamic>);
        }).toList();
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError = 'Không thể tải thông tin bộ đề từ máy chủ.',
        );
      }
    }
  }

  Future<void> _loadFavorite() async {
    try {
      await _attachToken();
      final response = await ApiClient().get(
        '/favorites/status',
        query: {'targetId': widget.quizSet.id, 'targetType': 'quizSet'},
      ) as Map<String, dynamic>;
      if (mounted) setState(() => _isFavorite = response['isFavorite'] == true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải trạng thái yêu thích.')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isFavoriteLoading = true);
    try {
      await _attachToken();
      if (_isFavorite) {
        await ApiClient().delete(
          '/favorites',
          query: {'targetId': widget.quizSet.id, 'targetType': 'quizSet'},
        );
      } else {
        await ApiClient().post('/favorites', {
          'targetId': widget.quizSet.id,
          'targetType': 'quizSet',
        });
      }
      if (mounted) setState(() => _isFavorite = !_isFavorite);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật yêu thích: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  // bộ 10 câu chuẩn tối đa 180đ, ghi cứng tạm
  int get maxScore => 180;

  Color get levelColor => AppColors.levelColor(_set.level);

  @override
  Widget build(BuildContext context) {
    final quizSet = _set;
    final topic = widget.topic;
    return Scaffold(
      appBar: AppBar(
        title: Text(quizSet.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadError != null)
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(_loadError!),
                trailing: IconButton(
                  tooltip: 'Thử lại',
                  onPressed: _loadRealSet,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
          // thẻ tiêu đề + mô tả + huy hiệu độ khó
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          quizSet.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          quizSet.levelLabel,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: levelColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    quizSet.description.isEmpty
                        ? 'Bộ đề ${topic.name}'
                        : quizSet.description,
                  ),
                  Text(
                    'Chủ đề: ${topic.name}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatBox(label: 'Số câu', value: '${quizSet.questionCount} câu'),
              _StatBox(
                label: 'Thời gian',
                value: '${quizSet.durationSec ~/ 60} phút',
              ),
              _StatBox(label: 'Độ khó', value: quizSet.levelLabel),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatBox(label: 'Điểm tối đa', value: '$maxScore điểm'),
              _StatBox(
                label: 'Lượt làm',
                value: '${quizSet.attemptCount} lượt',
              ),
              _StatBox(
                label: 'Điểm TB',
                value: quizSet.avgScore.toStringAsFixed(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizPlayScreen(quizSet: quizSet),
                        ),
                      );
                    },
                    child: const Text('Bắt đầu làm bài'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isFavorite
                        ? AppColors.error
                        : AppColors.primary,
                    side: BorderSide(
                      color: _isFavorite ? AppColors.error : AppColors.primary,
                    ),
                  ),
                  onPressed: _isFavoriteLoading ? null : _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? AppColors.error : AppColors.primary,
                  ),
                  label: Text(_isFavorite ? 'Đã thích' : 'Yêu thích'),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          const Text(
            'Đánh giá',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_reviews.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Chưa có đánh giá nào.'),
                subtitle: Text('Hãy là người đầu tiên đánh giá bộ đề này.'),
              ),
            )
          else
            ..._reviews.map(
              (r) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(r.userName[0])),
                  title: Text(r.userName),
                  subtitle: Text(r.comment),
                  trailing: Text('⭐' * r.rating),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}