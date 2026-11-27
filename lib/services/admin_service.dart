import 'package:firebase_auth/firebase_auth.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';
import '../models/leaderboard_model.dart';
import '../models/question_model.dart';
import '../models/quiz_set_model.dart';
import '../models/report_model.dart';
import '../models/topic_model.dart';
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

  Future<QuizSet> saveQuizSet(String? id, Map<String, dynamic> body) async {
    final data = id == null
        ? await _apiPost('/admin/quiz-sets', body)
        : await _apiPut('/admin/quiz-sets/$id', body);
    return QuizSet.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteQuizSet(String id) =>
      _apiDelete('/admin/quiz-sets/$id');

  Future<List<Question>> loadQuestions(String quizSetId) async {
    final data = await _get('/admin/quiz-sets/$quizSetId/questions');
    return _parseList(data, Question.fromJson);
  }

  Future<List<Topic>> loadTopics() async {
    final data = await _get('/admin/topics');
    return _parseList(data, Topic.fromJson);
  }

  Future<Topic> saveTopic(String? id, Map<String, dynamic> body) async {
    final data = id == null
        ? await _apiPost('/admin/topics', body)
        : await _apiPut('/admin/topics/$id', body);
    return Topic.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTopic(String id) => _apiDelete('/admin/topics/$id');

  Future<List<Question>> loadQuestionBank({
    String topicId = '',
    String search = '',
    String level = '',
  }) async {
    final query = <String, String>{
      if (topicId.isNotEmpty) 'topicId': topicId,
      if (search.isNotEmpty) 'search': search,
      if (level.isNotEmpty) 'level': level,
    };
    final data = await _get('/admin/questions', query: query);
    return _parseList(data, Question.fromJson);
  }

  Future<Question> loadQuestion(String id) async {
    final data = await _get('/admin/questions/$id');
    return Question.fromJson(data as Map<String, dynamic>);
  }

  Future<Question> saveQuestion(
    String? id,
    Map<String, dynamic> body,
  ) async {
    final data = id == null
        ? await _apiPost('/admin/questions', body)
        : await _apiPut('/admin/questions/$id', body);
    return Question.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteQuestion(String id) => _apiDelete('/admin/questions/$id');

  Future<List<ItemModel>> loadItems() async {
    final data = await _get('/admin/items');
    return _parseList(
      data,
      (json) => ItemModel.fromMap(json, json['id']?.toString() ?? ''),
    );
  }

  Future<ItemModel> saveItem(String? id, Map<String, dynamic> body) async {
    final data = id == null
        ? await _apiPost('/admin/items', body)
        : await _apiPut('/admin/items/$id', body);
    final json = data as Map<String, dynamic>;
    return ItemModel.fromMap(json, json['id']?.toString() ?? '');
  }

  Future<void> deleteItem(String id) => _apiDelete('/admin/items/$id');

  Future<List<UserModel>> loadUsers({String search = ''}) async {
    final data = await _get(
      '/admin/users',
      query: search.isEmpty ? null : {'search': search},
    );
    return _parseList(
      data,
      (json) => UserModel.fromMap(json, json['uid']?.toString() ?? ''),
    );
  }

  Future<List<ReportModel>> loadReports() async {
    final data = await _get('/admin/reports');
    return _parseList(data, ReportModel.fromMap);
  }

  Future<void> setUserStatus(String uid, String status) async {
    await _apiPut('/admin/users/$uid/status', {'status': status});
  }

  Future<void> setReportStatus(int id, String status) async {
    await _apiPut('/admin/reports/$id/status', {'status': status});
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    await _attachToken();
    return _api.get(path, query: query);
  }

  Future<dynamic> _apiPost(String path, Map<String, dynamic> body) async {
    await _attachToken();
    return _api.post(path, body);
  }

  Future<dynamic> _apiPut(String path, Map<String, dynamic> body) async {
    await _attachToken();
    return _api.put(path, body);
  }

  Future<void> _apiDelete(String path) async {
    await _attachToken();
    await _api.delete(path);
  }

  Future<void> _attachToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bạn cần đăng nhập để sử dụng trang quản trị.');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
    }
    _api.setToken(token);
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