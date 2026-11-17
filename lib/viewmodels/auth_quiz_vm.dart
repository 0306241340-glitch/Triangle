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

  int get total => questions.length;
  Question? get currentQuestion =>
      questions.isEmpty ? null : questions[currentIndex];
  bool get isLast => currentIndex == total - 1;

  String get timeText {
    final m = remainingSec ~/ 60;
    final s = remainingSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> load(String quizSetId) async {
    this.quizSetId = quizSetId;
    isLoading = true;
    notifyListeners();
    try {
      final data = await _api.post('/quiz/start', {'quizSetId': quizSetId});

      attemptId = data['attemptId'] as String?;
      remainingSec = (data['durationSec'] as num?)?.toInt() ?? 300;
      userCoins = (data['userCoins'] as num?)?.toInt() ?? userCoins;
      questions = (data['questions'] as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      questions = List.of(_mockMathQuestions);
      remainingSec = 300;
    }
    _initialDuration = remainingSec;
    isLoading = false;
    notifyListeners();
    _startTimer();
  }

  void _startTimer() {
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

  /// Trợ giúp 1: 50/50 — ẩn 2 đáp án sai (30 xu). Mỗi câu chỉ dùng 1 lần.
  /// Trả về chuỗi lỗi nếu thất bại, null nếu thành công.
  String? useFiftyFifty() {
    final q = currentQuestion;
    if (q == null) return 'Không có câu hỏi';
    if (hiddenOptions.containsKey(currentIndex))
      return 'Câu này đã dùng 50/50 rồi';
    if (userCoins < 30) return 'Không đủ xu (cần 30, còn $userCoins xu)';
    final wrong = [0, 1, 2, 3]
        .where((i) => i != q.correctIndex && answers[currentIndex] != i)
        .take(2)
        .toSet();
    hiddenOptions[currentIndex] = wrong;
    userCoins -= 30;
    notifyListeners();
    return null; // thành công
  }

  /// Trợ giúp 2: Thêm thời gian — cộng 30 giây (20 xu). Cả bài chỉ dùng 1 lần.
  String? useExtraTime() {
    if (usedExtraTime) return 'Đã dùng Thêm thời gian rồi';
    if (userCoins < 20) return 'Không đủ xu (cần 20, còn $userCoins xu)';
    remainingSec += 30;
    userCoins -= 20;
    usedExtraTime = true;
    notifyListeners();
    return null; // thành công
  }

  /// Trợ giúp 3: Đổi câu hỏi — thay câu hiện tại bằng câu khác cùng chủ đề
  /// (30 xu). Mỗi câu chỉ đổi 1 lần. Demo offline: hoán vị câu cuối sang vị
  /// trí hiện tại. Khi API deploy: gọi /quiz/change-question.
  String? useChangeQuestion() {
    if (changedQuestions.contains(currentIndex)) return 'Câu này đã đổi rồi';
    if (userCoins < 30) return 'Không đủ xu (cần 30, còn $userCoins xu)';
    // Demo offline: hoán vị câu hiện tại với câu cuối chưa đổi
    final swapTarget = questions.lastIndexWhere(
      (q) =>
          q.topicId == currentQuestion!.topicId &&
          questions.indexOf(q) != currentIndex,
    );
    if (swapTarget >= 0 && swapTarget != currentIndex) {
      final tmp = questions[currentIndex];
      questions[currentIndex] = questions[swapTarget];
      questions[swapTarget] = tmp;
      // Xóa đáp án cũ + 50/50 cũ của câu này vì đã đổi nội dung
      answers.remove(currentIndex);
      hiddenOptions.remove(currentIndex);
    }
    changedQuestions.add(currentIndex);
    userCoins -= 30;
    notifyListeners();
    return null; // thành công
  }

  bool isHidden(int questionIndex, int optionIndex) =>
      hiddenOptions[questionIndex]?.contains(optionIndex) ?? false;

  // ──────────────────────────────────────────────────────────────────

  Future<void> submit() async {
    if (submitted || _submitting) return;
    _submitting = true;
    _timer?.cancel();
    submitted = true;
    final timeTakenSec = _initialDuration - remainingSec;
    try {
      if (attemptId != null) {
        final data = await _api.post('/quiz/submit', {
          'attemptId': attemptId,
          'quizSetId': quizSetId,
          'answers': [
            for (final e in answers.entries)
              {'questionId': questions[e.key].id, 'selectedIndex': e.value},
          ],
          'timeTakenSec': timeTakenSec,
        });
        score = (data['score'] as num?)?.toInt() ?? 0;
        coins = (data['coinsEarned'] as num?)?.toInt() ?? 0;
        correctCount = (data['correctCount'] as num?)?.toInt() ?? 0;
        skippedCount =
            total -
            ((data['answeredCount'] as num?)?.toInt() ?? answers.length);
      } else {
        _scoreLocally();
      }
    } catch (_) {
      _scoreLocally();
    }
    _submitting = false;
    notifyListeners();
  }

  void _scoreLocally() {
    score = 0;
    coins = 0;
    correctCount = 0;
    skippedCount = total - answers.length;
    for (final e in answers.entries) {
      final q = questions[e.key];
      if (e.value == q.correctIndex) {
        correctCount++;
        score += q.points;
        coins += q.coins;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 10 câu Toán thật trong seed-data.json (4 Dễ / 4 TB / 2 Khó = 180đ / 90xu).
  static const _mockMathQuestions = [
    Question(
      id: 'q_math_01',
      topicId: 'topic_math',
      content: '7 + 8 bằng bao nhiêu?',
      options: ['14', '15', '16', '17'],
      correctIndex: 1,
      level: 'easy',
      explanation: '7 + 8 = 15.',
    ),
    Question(
      id: 'q_math_02',
      topicId: 'topic_math',
      content: '12 × 3 bằng bao nhiêu?',
      options: ['33', '36', '39', '42'],
      correctIndex: 1,
      level: 'easy',
      explanation: '12 × 3 = 36.',
    ),
    Question(
      id: 'q_math_03',
      topicId: 'topic_math',
      content: '100 − 37 bằng bao nhiêu?',
      options: ['63', '67', '73', '53'],
      correctIndex: 0,
      level: 'easy',
      explanation: '100 − 37 = 63.',
    ),
    Question(
      id: 'q_math_04',
      topicId: 'topic_math',
      content: '5² bằng bao nhiêu?',
      options: ['10', '20', '25', '30'],
      correctIndex: 2,
      level: 'easy',
      explanation: '5² = 5 × 5 = 25.',
    ),
    Question(
      id: 'q_math_05',
      topicId: 'topic_math',
      content: 'Căn bậc hai của 144 bằng bao nhiêu?',
      options: ['11', '12', '13', '14'],
      correctIndex: 1,
      level: 'medium',
      explanation: '12 × 12 = 144 nên √144 = 12.',
    ),
    Question(
      id: 'q_math_06',
      topicId: 'topic_math',
      content: '3/4 của 80 bằng bao nhiêu?',
      options: ['50', '55', '60', '65'],
      correctIndex: 2,
      level: 'medium',
      explanation: '80 × 3/4 = 60.',
    ),
    Question(
      id: 'q_math_07',
      topicId: 'topic_math',
      content: 'Giải phương trình 2x + 5 = 17, x bằng bao nhiêu?',
      options: ['5', '6', '7', '8'],
      correctIndex: 1,
      level: 'medium',
      explanation: '2x = 12 nên x = 6.',
    ),
    Question(
      id: 'q_math_08',
      topicId: 'topic_math',
      content: '15% của 200 bằng bao nhiêu?',
      options: ['20', '25', '30', '35'],
      correctIndex: 2,
      level: 'medium',
      explanation: '200 × 15% = 30.',
    ),
    Question(
      id: 'q_math_09',
      topicId: 'topic_math',
      content: 'Tổng 1 + 2 + ... + 20 bằng bao nhiêu?',
      options: ['200', '210', '220', '190'],
      correctIndex: 1,
      level: 'hard',
      explanation: 'Tổng = 20 × 21 / 2 = 210.',
    ),
    Question(
      id: 'q_math_10',
      topicId: 'topic_math',
      content: '2 mũ bao nhiêu thì bằng 128?',
      options: ['6', '7', '8', '9'],
      correctIndex: 1,
      level: 'hard',
      explanation: '2^7 = 128.',
    ),
  ];
}
