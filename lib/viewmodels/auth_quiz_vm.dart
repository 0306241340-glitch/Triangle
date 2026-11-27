import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/question_model.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? auth}) : _auth = auth ?? AuthService();

  final AuthService _auth;
  bool isLoading = false;
  String? error;

  Future<bool> signIn(String email, String password) async {
    return _run(() => _auth.signInWithEmail(email, password));
  }

  Future<bool> signUp(String email, String password) async {
    return _run(() => _auth.signUpWithEmail(email, password));
  }

  Future<bool> signInWithGoogle() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final cred = await _auth.signInWithGoogle();
      return cred != null;
    } on FirebaseAuthException catch (e) {
      error = _message(e.code);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    return _run(() => _auth.sendPasswordResetEmail(email));
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on FirebaseAuthException catch (e) {
      error = _message(e.code);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _message(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu chưa đúng';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký';
      case 'weak-password':
        return 'Mật khẩu phải từ 6 ký tự trở lên';
      case 'invalid-email':
        return 'Email chưa đúng định dạng';
      case 'network-request-failed':
        return 'Không có mạng, kiểm tra Wi-Fi rồi thử lại';
      default:
        return 'Có lỗi xảy ra, thử lại sau ($code)';
    }
  }
}

class QuizPlayViewModel extends ChangeNotifier {
  QuizPlayViewModel({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  bool isLoading = false;
  String? error;
  String? submitError;
  List<Question> questions = [];
  Map<int, int> answers = {}; // index câu -> index đáp án đã chọn
  Map<int, Set<int>> hiddenOptions = {}; // 50/50: đáp án bị ẩn của từng câu
  int currentIndex = 0;
  int remainingSec = 300;
  int _initialDuration = 300;
  Timer? _timer;
  bool _submitting = false;
  String? attemptId;
  String? quizSetId;
  bool submitted = false;
  int score = 0;
  int coins = 0;
  int correctCount = 0;
  int skippedCount = 0;

  /// Xu hiện có của user — hiển thị trên thanh AppBar khi thi.
  /// Khởi tạo = 100 (seed mặc định). API deploy thì load() lấy từ server.
  int userCoins = 100;

  /// Đếm số lần đã dùng mỗi loại trợ giúp (toàn bài, không phải từng câu).
  bool usedExtraTime = false; // Thêm thời gian: dùng 1 lần / bài
  Set<int> changedQuestions = {}; // Đổi câu hỏi: mỗi câu chỉ đổi 1 lần
  String? activeHelp; // Loại trợ giúp đang chờ máy chủ xử lý
  Map<String, int> correctIndices = {}; // questionId -> chỉ số đáp án đúng (sau khi nộp)

  bool get isUsingHelp => activeHelp != null;
  bool get isSubmitting => _submitting;

  int get total => questions.length;
  Question? get currentQuestion =>
      questions.isEmpty ? null : questions[currentIndex];
  bool get isLast => currentIndex == total - 1;

  String get timeText {
    final m = remainingSec ~/ 60;
    final s = remainingSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> load(String quizSetId, {String? topicId}) async {
    this.quizSetId = quizSetId;
    isLoading = true;
    error = null;
    questions = [];
    answers.clear();
    hiddenOptions.clear();
    changedQuestions.clear();
    correctIndices.clear();
    attemptId = null;
    submitted = false;
    submitError = null;
    usedExtraTime = false;
    activeHelp = null;
    currentIndex = 0;
    remainingSec = 300;
    score = 0;
    coins = 0;
    correctCount = 0;
    skippedCount = 0;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    try {
      if (user == null) {
        throw StateError('Bạn cần đăng nhập để bắt đầu làm bài.');
      }
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw StateError('Không lấy được phiên đăng nhập. Hãy đăng nhập lại.');
      }
      _api.setToken(token);

      final profile = await _api.get('/me') as Map<String, dynamic>;
      userCoins = (profile['coins'] as num?)?.toInt() ?? userCoins;
      final quizSet =
          await _api.get('/quiz-sets/$quizSetId') as Map<String, dynamic>;
      final duration = (quizSet['durationSec'] as num?)?.toInt();
      if (duration != null && duration > 0) remainingSec = duration;
      final response = await _api.post('/quiz/start', {
        'quizSetId': quizSetId,
        if (topicId != null) 'topicId': topicId,
      });
      final data = response as Map<String, dynamic>;
      attemptId = data['attemptId'] as String?;
      if (attemptId == null || attemptId!.isEmpty) {
        throw StateError('Máy chủ không tạo được lượt chơi.');
      }
      remainingSec = (data['durationSec'] as num?)?.toInt() ?? remainingSec;
      final serverCoins = (data['userCoins'] as num?)?.toInt();
      if (serverCoins != null) userCoins = serverCoins;
      questions = (data['questions'] as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
      if (questions.isEmpty) {
        throw StateError('Bộ đề chưa có câu hỏi đang hoạt động.');
      }
      _initialDuration = remainingSec;
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
    if (error == null) _startTimer();
  }

  void _startTimer() {
    if (remainingSec <= 0) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (remainingSec <= 0) {
        t.cancel();
        submit();
        return;
      }
      remainingSec--;
      notifyListeners();
    });
  }

  void selectAnswer(int optionIndex) {
    answers[currentIndex] = optionIndex;
    notifyListeners();
  }

  void goTo(int index) {
    if (index < 0 || index >= total) return;
    currentIndex = index;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────
  // 3 QUYỀN TRỢ GIÚP (BF03) — đúng tài liệu đặc tả + seed-data
  // ──────────────────────────────────────────────────────────────────

  /// Trả về chuỗi lỗi nếu yêu cầu trợ giúp thất bại.
  Future<String?> useFiftyFifty() async {
    if (isUsingHelp) return null;
    final q = currentQuestion;
    if (q == null) return 'Không có câu hỏi';
    if (hiddenOptions.containsKey(currentIndex))
      return 'Câu này đã dùng 50/50 rồi';
    if (userCoins < 30) return 'Không đủ xu (cần 30, còn $userCoins xu)';
    activeHelp = 'fifty_fifty';
    notifyListeners();
    try {
      if (attemptId == null) {
        throw StateError('Lượt chơi chưa được lưu trên máy chủ.');
      }
      final data = await _api.post('/quiz/fifty-fifty', {
        'attemptId': attemptId,
        'questionId': q.id,
        'selectedIndex': answers[currentIndex],
      });
      final hide = (data['hiddenIndices'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      hiddenOptions[currentIndex] = hide;
      userCoins = (data['coins'] as num?)?.toInt() ?? userCoins;
      return null;
    } catch (error) {
      return error.toString();
    } finally {
      activeHelp = null;
      notifyListeners();
    }
  }

  /// Trợ giúp 2: Thêm thời gian — cập nhật lạc quan ngay trên UI, đồng bộ/hoàn tác theo máy chủ.
  Future<String?> useExtraTime() async {
    if (isUsingHelp) return null;
    if (usedExtraTime) return 'Đã dùng Thêm thời gian rồi';
    if (userCoins < 20) return 'Không đủ xu (cần 20, còn $userCoins xu)';

    const optimisticAdded = 30;
    const cost = 20;
    final prevCoins = userCoins;
    remainingSec += optimisticAdded;
    userCoins -= cost;
    usedExtraTime = true;
    activeHelp = 'extra_time';
    notifyListeners();

    try {
      final data = await _useServerHelp('extra_time');
      final serverAdded = (data['addedSeconds'] as num?)?.toInt() ?? optimisticAdded;
      if (serverAdded != optimisticAdded) {
        remainingSec += (serverAdded - optimisticAdded);
      }
      userCoins = (data['coins'] as num?)?.toInt() ?? userCoins;
      return null;
    } catch (error) {
      remainingSec = (remainingSec - optimisticAdded).clamp(0, 1 << 30);
      userCoins = prevCoins;
      usedExtraTime = false;
      return error.toString();
    } finally {
      activeHelp = null;
      notifyListeners();
    }
  }

  /// Trợ giúp 3: Yêu cầu máy chủ thay câu và trừ xu trong cùng giao dịch.
  Future<String?> useChangeQuestion() async {
    if (isUsingHelp) return null;
    if (changedQuestions.contains(currentIndex)) return 'Câu này đã đổi rồi';
    if (userCoins < 30) return 'Không đủ xu (cần 30, còn $userCoins xu)';
    final oldQuestion = currentQuestion;
    if (oldQuestion == null) return 'Không có câu hỏi';
    activeHelp = 'change_question';
    notifyListeners();
    try {
      final data = await _useServerHelp(
        'change_question',
        questionId: oldQuestion.id,
        answerId: oldQuestion.slotId,
      );
      final replacement = Question.fromJson(
        data['question'] as Map<String, dynamic>,
      );
      final otherQuestion = Question.fromJson(
        data['otherQuestion'] as Map<String, dynamic>,
      );
      final otherIndex = questions.indexWhere(
        (question) => question.slotId == otherQuestion.slotId,
      );
      if (otherIndex < 0 || otherIndex == currentIndex) {
        throw StateError('Không tìm thấy câu hỏi được đổi trong bộ đề.');
      }
      questions[currentIndex] = replacement;
      questions[otherIndex] = otherQuestion;
      answers.remove(currentIndex);
      answers.remove(otherIndex);
      hiddenOptions.remove(currentIndex);
      hiddenOptions.remove(otherIndex);
      changedQuestions.add(currentIndex);
      changedQuestions.add(otherIndex);
      userCoins = (data['coins'] as num?)?.toInt() ?? userCoins;
      return null;
    } catch (error) {
      return error.toString();
    } finally {
      activeHelp = null;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _useServerHelp(
    String helpType, {
    String questionId = '',
    String answerId = '',
  }) async {
    final id = attemptId;
    if (id == null) throw StateError('Lượt chơi chưa được lưu trên máy chủ.');
    return await _api.post('/quiz/help', {
      'attemptId': id,
      'questionId': questionId,
      'answerId': answerId,
      'helpType': helpType,
    }) as Map<String, dynamic>;
  }

  bool isHidden(int questionIndex, int optionIndex) =>
      hiddenOptions[questionIndex]?.contains(optionIndex) ?? false;

  // ──────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (submitted || _submitting || attemptId == null) return;
    _submitting = true;
    _timer?.cancel();
    submitError = null;
    notifyListeners();
    final elapsed = _initialDuration - remainingSec;
    final timeTakenSec = elapsed < 0 ? 0 : elapsed;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final token = await currentUser?.getIdToken();
      if (token == null || token.isEmpty) {
        throw StateError('Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.');
      }
      _api.setToken(token);
      final data = await _api.post('/quiz/submit', {
        'attemptId': attemptId,
        'quizSetId': quizSetId,
        'answers': [
          for (final entry in answers.entries)
            {
              'questionId': questions[entry.key].id,
              'selectedIndex': entry.value,
            },
        ],
        'timeTakenSec': timeTakenSec,
      }) as Map<String, dynamic>;
      score = (data['score'] as num?)?.toInt() ?? 0;
      coins = (data['coinsEarned'] as num?)?.toInt() ?? 0;
      correctCount = (data['correctCount'] as num?)?.toInt() ?? 0;
      userCoins = (data['userCoins'] as num?)?.toInt() ?? userCoins;
      skippedCount =
          total - ((data['answeredCount'] as num?)?.toInt() ?? answers.length);
      final rawCorrect = data['correctIndices'];
      if (rawCorrect is Map) {
        correctIndices = {
          for (final e in rawCorrect.entries)
            e.key.toString(): (e.value as num).toInt(),
        };
      }
      submitted = true;
    } catch (error) {
      submitError = error.toString();
      if (remainingSec > 0) _startTimer();
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
