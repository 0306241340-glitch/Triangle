import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/item_model.dart';
import '../models/leaderboard_model.dart';
import '../models/question_model.dart';
import '../models/quiz_set_model.dart';
import '../models/report_model.dart';
import '../models/topic_model.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';

class AdminViewModel extends ChangeNotifier {
  AdminViewModel({AdminService? service}) : _service = service ?? AdminService();

  final AdminService _service;

  bool isLoadingStats = false;
  bool isLoadingQuizSets = false;
  bool isLoadingTopics = false;
  bool isLoadingQuestionBank = false;
  bool isLoadingItems = false;
  bool isLoadingUsers = false;
  bool isLoadingReports = false;
  bool isMutating = false;
  final Set<String> loadingQuestionSets = {};

  String? statsError;
  String? quizSetsError;
  String? topicsError;
  String? questionBankError;
  String? itemsError;
  String? usersError;
  String? reportsError;
  String? mutationError;
  final Map<String, String> questionErrors = {};

  AdminStats? stats;
  List<QuizSet> quizSets = [];
  List<Topic> topics = [];
  List<Question> questionBank = [];
  List<ItemModel> items = [];
  List<UserModel> users = [];
  List<ReportModel> reports = [];
  final Map<String, List<Question>> questionsByQuizSet = {};
  String userSearch = '';

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

  Future<void> loadTopics() => _load(
    setLoading: (value) => isLoadingTopics = value,
    setError: (value) => topicsError = value,
    load: () async => topics = await _service.loadTopics(),
    fallback: 'Không tải được chủ đề, thử lại sau',
  );

  Future<void> loadQuestionBank({
    String topicId = '',
    String search = '',
    String level = '',
  }) async {
    isLoadingQuestionBank = true;
    questionBankError = null;
    notifyListeners();
    try {
      questionBank = await _service.loadQuestionBank(
        topicId: topicId,
        search: search,
        level: level,
      );
    } on ApiException catch (error) {
      questionBankError = _adminError(error);
    } catch (_) {
      questionBankError = 'Không tải được ngân hàng câu hỏi, thử lại sau';
    } finally {
      isLoadingQuestionBank = false;
      notifyListeners();
    }
  }

  Future<List<Question>> questionsForTopic(String topicId) =>
      _service.loadQuestionBank(topicId: topicId);

  Future<Question> loadQuestion(String id) => _service.loadQuestion(id);

  Future<void> loadItems() => _load(
    setLoading: (value) => isLoadingItems = value,
    setError: (value) => itemsError = value,
    load: () async => items = await _service.loadItems(),
    fallback: 'Không tải được vật phẩm, thử lại sau',
  );

  Future<void> loadUsers({String? search}) async {
    userSearch = search ?? userSearch;
    await _load(
      setLoading: (value) => isLoadingUsers = value,
      setError: (value) => usersError = value,
      load: () async => users = await _service.loadUsers(search: userSearch),
      fallback: 'Không tải được tài khoản, thử lại sau',
    );
  }

  Future<void> loadReports() => _load(
    setLoading: (value) => isLoadingReports = value,
    setError: (value) => reportsError = value,
    load: () async => reports = await _service.loadReports(),
    fallback: 'Không tải được báo lỗi, thử lại sau',
  );

  Future<void> loadQuestions(QuizSet quizSet, {bool force = false}) async {
    if ((!force && questionsByQuizSet.containsKey(quizSet.id)) ||
        loadingQuestionSets.contains(quizSet.id)) {
      return;
    }
    loadingQuestionSets.add(quizSet.id);
    questionErrors.remove(quizSet.id);
    notifyListeners();
    try {
      questionsByQuizSet[quizSet.id] = await _service.loadQuestions(
        quizSet.id,
      );
    } on ApiException catch (error) {
      questionErrors[quizSet.id] = _adminError(error);
    } catch (_) {
      questionErrors[quizSet.id] = 'Không tải được câu hỏi, thử lại sau';
    } finally {
      loadingQuestionSets.remove(quizSet.id);
      notifyListeners();
    }
  }

  Future<QuizSet> saveQuizSet(String? id, Map<String, dynamic> body) async {
    final saved = await _service.saveQuizSet(id, body);
    _replaceOrAdd(quizSets, id, saved, (row) => row.id);
    questionsByQuizSet.remove(saved.id);
    notifyListeners();
    return saved;
  }

  Future<void> deleteQuizSet(String id) async {
    await _service.deleteQuizSet(id);
    quizSets.removeWhere((row) => row.id == id);
    questionsByQuizSet.remove(id);
    notifyListeners();
  }

  Future<Topic> saveTopic(String? id, Map<String, dynamic> body) async {
    final saved = await _service.saveTopic(id, body);
    _replaceOrAdd(topics, id, saved, (row) => row.id);
    notifyListeners();
    return saved;
  }

  Future<void> deleteTopic(String id) async {
    await _service.deleteTopic(id);
    topics.removeWhere((row) => row.id == id);
    notifyListeners();
  }

  Future<Question> saveQuestion(
    String? id,
    Map<String, dynamic> body,
  ) async {
    final saved = await _service.saveQuestion(id, body);
    _replaceOrAdd(questionBank, id, saved, (row) => row.id);
    questionsByQuizSet.clear();
    await loadTopics();
    notifyListeners();
    return saved;
  }

  Future<void> deleteQuestion(String id) async {
    await _service.deleteQuestion(id);
    questionBank.removeWhere((row) => row.id == id);
    questionsByQuizSet.clear();
    await loadTopics();
    notifyListeners();
  }

  Future<ItemModel> saveItem(String? id, Map<String, dynamic> body) async {
    final saved = await _service.saveItem(id, body);
    _replaceOrAdd(items, id, saved, (row) => row.id);
    notifyListeners();
    return saved;
  }

  Future<void> deleteItem(String id) async {
    await _service.deleteItem(id);
    items.removeWhere((row) => row.id == id);
    notifyListeners();
  }

  Future<void> setUserStatus(UserModel user, String status) async {
    await _service.setUserStatus(user.uid, status);
    users = await _service.loadUsers(search: userSearch);
    notifyListeners();
  }

  Future<void> setReportStatus(ReportModel report, String status) async {
    await _service.setReportStatus(report.id, status);
    reports = await _service.loadReports();
    notifyListeners();
  }

  Future<bool> performMutation(Future<void> Function() action) async {
    isMutating = true;
    mutationError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      mutationError = _adminError(error);
      return false;
    } catch (error) {
      mutationError = error is StateError
          ? error.message
          : 'Thao tác thất bại, vui lòng thử lại.';
      return false;
    } finally {
      isMutating = false;
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

  void _replaceOrAdd<T>(
    List<T> rows,
    String? id,
    T value,
    String Function(T) getId,
  ) {
    final index = id == null ? -1 : rows.indexWhere((row) => getId(row) == id);
    if (index < 0) {
      rows.insert(0, value);
    } else {
      rows[index] = value;
    }
  }

  String _adminError(ApiException error) => error.statusCode == 403
      ? 'Chỉ quản trị viên mới thực hiện được thao tác này'
      : error.message;
}
