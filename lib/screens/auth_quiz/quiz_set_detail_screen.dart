import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_constants.dart';
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
  late QuizSet _set;
  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _set = widget.quizSet;
    _loadRealSet();
    _loadFavoriteStatus();
  }

  // Gọi GET /favorites/ids từ FastAPI để kiểm tra bộ đề này đã thích chưa
  Future<void> _loadFavoriteStatus() async {
    try {
      final data = await ApiClient()
          .get('/favorites/ids')
          .timeout(const Duration(seconds: 3));
      final ids = (data as List? ?? []).map((e) => e.toString()).toList();
      if (mounted) {
        setState(() {
          _isFavorite = ids.contains(widget.quizSet.id);
        });
      }
    } catch (e) {
      debugPrint('[QuizSetDetail] Lỗi load favorite ids từ API: $e');
    }
  }

  // Gọi POST /favorites/{set_id}/toggle sang FastAPI + PostgreSQL
  Future<void> _toggleFavorite() async {
    final prevState = _isFavorite;
    setState(() => _isFavorite = !prevState);

    try {
      final res = await ApiClient()
          .post('/favorites/${widget.quizSet.id}/toggle', const {})
          .timeout(const Duration(seconds: 3));

      if (mounted &&
          res is Map<String, dynamic> &&
          res.containsKey('isFavorite')) {
        setState(() {
          _isFavorite = res['isFavorite'] == true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFavorite = prevState);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối server: $e')),
        );
      }
    }
  }

  // Lấy bộ đề thật từ API hoặc Firestore (số lượt làm, điểm TB, bình luận).
  Future<void> _loadRealSet() async {
    // 1. Thử gọi API
    try {
      final data = await ApiClient()
          .get('/quiz-sets/${widget.quizSet.id}')
          .timeout(const Duration(seconds: 3));
      final m = data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _set = QuizSet.fromJson(m);
        _reviews = (m['comments'] as List? ?? []).map((e) {
          final c = e as Map<String, dynamic>;
          return Review(
            id: c['id']?.toString() ?? '',
            quizSetId: c['quizSetId']?.toString() ?? widget.quizSet.id,
            userName: c['userName']?.toString() ?? 'Người chơi',
            rating: (c['rating'] as num?)?.toInt() ?? 5,
            comment: c['comment']?.toString() ?? '',
            createdAt: c['createdAt']?.toString() ?? '',
          );
        }).toList();
      });
      return;
    } catch (_) {
      // API lỗi, thử Firestore
    }

    // 2. Thử đọc từ Firestore quiz_sets
    try {
      final snap = await FirebaseFirestore.instance
          .collection(AppConstants.quizSetsCollection)
          .doc(widget.quizSet.id)
          .get();
      if (snap.exists && mounted) {
        setState(() {
          _set = QuizSet.fromJson({...snap.data()!, 'id': snap.id});
        });
      }
    } catch (e) {
      debugPrint('[QuizSetDetail] Lỗi load Firestore: $e');
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
                  onPressed: _toggleFavorite,
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