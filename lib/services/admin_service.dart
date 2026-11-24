import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';
import '../models/leaderboard_model.dart';
import '../models/question_model.dart';
import '../models/quiz_set_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';

class AdminService {
  AdminService({ApiClient? api, FirebaseAuth? auth})
    : _api = api ?? ApiClient(),
      _auth = auth ?? FirebaseAuth.instance;

  final ApiClient _api;
  final FirebaseAuth _auth;

  Future<AdminStats> loadStats() async {
    final data = await _get('/admin/stats');
    return AdminStats.fromJson(data as Map<String, dynamic>);
  }

  Future<List<QuizSet>> loadQuizSets() async {
    final data = await _get('/admin/quiz-sets');
    return _parseList(data, QuizSet.fromJson);
  }

  Future<List<Question>> loadQuestions(String quizSetId) async {
    final data = await _get('/admin/quiz-sets/$quizSetId/questions');
    return _parseList(data, Question.fromJson);
  }

  Future<List<ItemModel>> loadItems() async {
    final data = await _get('/admin/items');
    return _parseList(
      data,
      (json) => ItemModel.fromMap(json, json['id']?.toString() ?? ''),
    );
  }

  Future<List<UserModel>> loadUsers() async {
    final data = await _get('/admin/users');
    return _parseList(
      data,
      (json) => UserModel.fromMap(json, json['uid']?.toString() ?? ''),
    );
  }

  Future<List<ReportModel>> loadReports() async {
    final data = await _get('/admin/reports');
    return _parseList(data, ReportModel.fromMap);
  }

  Future<dynamic> _get(String path) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để sử dụng trang quản trị.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(token);
    return _api.get(path);
  }

  List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is! List) {
      throw const FormatException('Dữ liệu danh sách quản trị không hợp lệ.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }
}