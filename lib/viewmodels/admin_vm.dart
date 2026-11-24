import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';
import '../models/leaderboard_model.dart';
import '../models/question_model.dart';
import '../models/quiz_set_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';

class AdminViewModel extends ChangeNotifier {
  AdminViewModel({AdminService? service})
    : _service = service ?? AdminService();

  final AdminService _service;

  bool isLoadingStats = false;
  bool isLoadingQuizSets = false;
  bool isLoadingItems = false;
  bool isLoadingUsers = false;
  bool isLoadingReports = false;
  final Set<String> loadingQuestionSets = {};

  String? statsError;
  String? quizSetsError;
  String? itemsError;
  String? usersError;
  String? reportsError;
  final Map<String, String> questionErrors = {};

  AdminStats? stats;
  List<QuizSet> quizSets = [];
  List<ItemModel> items = [];
  List<UserModel> users = [];
  List<ReportModel> reports = [];
  final Map<String, List<Question>> questionsByQuizSet = {};

  Future<void> loadTab(int index) {
    switch (index) {
      case 0:
        return loadQuizSets();
      case 1:
        return loadItems();
      case 2:
        return loadUsers();
      case 3:
        return loadReports();
      case 4:
        return loadStats();
      default:
        return Future<void>.value();
    }
  }

  Future<void> loadStats() => _load(
    setLoading: (value) => isLoadingStats = value,
    setError: (value) => statsError = value,
    load: () async => stats = await _service.loadStats(),
    fallback: 'Không tải được thống kê, thử lại sau',
  );

  Future<void> loadQuizSets() => _load(
    setLoading: (value) => isLoadingQuizSets = value,
    setError: (value) => quizSetsError = value,
    load: () async => quizSets = await _service.loadQuizSets(),
    fallback: 'Không tải được bộ đề, thử lại sau',
  );

  Future<void> loadItems() => _load(
    setLoading: (value) => isLoadingItems = value,
    setError: (value) => itemsError = value,
    load: () async => items = await _service.loadItems(),
    fallback: 'Không tải được vật phẩm, thử lại sau',
  );

  Future<void> loadUsers() => _load(
    setLoading: (value) => isLoadingUsers = value,
    setError: (value) => usersError = value,
    load: () async => users = await _service.loadUsers(),
    fallback: 'Không tải được tài khoản, thử lại sau',
  );

  Future<void> loadReports() => _load(
    setLoading: (value) => isLoadingReports = value,
    setError: (value) => reportsError = value,
    load: () async => reports = await _service.loadReports(),
    fallback: 'Không tải được báo lỗi, thử lại sau',
  );

  Future<void> loadQuestions(QuizSet quizSet) async {
    if (questionsByQuizSet.containsKey(quizSet.id) ||
        loadingQuestionSets.contains(quizSet.id)) {
      return;
    }
    loadingQuestionSets.add(quizSet.id);
    questionErrors.remove(quizSet.id);
    notifyListeners();
    try {
      questionsByQuizSet[quizSet.id] = await _service.loadQuestions(quizSet.id);
    } on ApiException catch (error) {
      questionErrors[quizSet.id] = _adminError(error);
    } catch (_) {
      questionErrors[quizSet.id] = 'Không tải được câu hỏi, thử lại sau';
    } finally {
      loadingQuestionSets.remove(quizSet.id);
      notifyListeners();
    }
  }

  Future<void> _load({
    required void Function(bool) setLoading,
    required void Function(String?) setError,
    required Future<void> Function() load,
    required String fallback,
  }) async {
    setLoading(true);
    setError(null);
    notifyListeners();
    try {
      await load();
    } on ApiException catch (error) {
      setError(_adminError(error));
    } catch (_) {
      setError(fallback);
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  String _adminError(ApiException error) => error.statusCode == 403
      ? 'Chỉ quản trị viên mới xem được mục này'
      : error.message;
}
