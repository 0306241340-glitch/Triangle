import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/app_constants.dart';
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

  Future<void> load(String quizSetId, {String? topicId}) async {
    this.quizSetId = quizSetId;
    isLoading = true;
    error = null;
    notifyListeners();

    // Suy luận topicId từ quizSetId nếu chưa truyền
    String effectiveTopicId = topicId ?? '';
    if (effectiveTopicId.isEmpty) {
      if (quizSetId.contains('do_meo')) {
        effectiveTopicId = 'topic_do_meo';
      } else if (quizSetId.contains('giai_tri')) {
        effectiveTopicId = 'topic_giai_tri';
      } else {
        effectiveTopicId = 'topic_tong_hop';
      }
    }

    final db = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    // ── Bước 1: Gán Firebase ID Token vào ApiClient ──
    try {
      if (user != null) {
        final token = await user.getIdToken(true);
        _api.setToken(token);
      }
    } catch (e) {
      debugPrint('[QuizVM] Không lấy được Firebase token: $e');
    }

    // ── Bước 2: Lấy số xu từ Firestore users/{uid} ──
    try {
      if (user != null) {
        final snap = await db
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();
        final coins = (snap.data()?['coins'] as num?)?.toInt();
        if (coins != null) userCoins = coins;
      }
    } catch (e) {
      debugPrint('[QuizVM] Không lấy được coins từ Firestore: $e');
    }

    // ── Bước 3: Đọc thông tin bộ đề từ Firestore quiz_sets (thời gian, topic) ──
    try {
      final setSnap = await db
          .collection(AppConstants.quizSetsCollection)
          .doc(quizSetId)
          .get();
      if (setSnap.exists) {
        final data = setSnap.data()!;
        final tId = data['topicId'] as String?;
        if (tId != null && tId.isNotEmpty) effectiveTopicId = tId;
        final dSec = (data['durationSec'] as num?)?.toInt();
        if (dSec != null && dSec > 0) remainingSec = dSec;
      }
    } catch (e) {
      debugPrint('[QuizVM] Không đọc được quiz_set từ Firestore: $e');
    }

    // ── Bước 4: Thử gọi API lấy câu hỏi từ server (timeout 60s cho Render khởi động) ──
    bool apiSuccess = false;
    try {
      final data = await _api
          .post('/quiz/start', {'quizSetId': quizSetId})
          .timeout(const Duration(seconds: 60));

      attemptId = data['attemptId'] as String?;
      remainingSec = (data['durationSec'] as num?)?.toInt() ?? remainingSec;
      final serverCoins = (data['userCoins'] as num?)?.toInt();
      if (serverCoins != null) userCoins = serverCoins;
      questions = (data['questions'] as List)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList();
      apiSuccess = true;
      debugPrint(
        '[QuizVM] Tải ${questions.length} câu từ API server thành công',
      );
    } catch (e) {
      debugPrint(
        '[QuizVM] API server không phản hồi ($e), thử đọc Firestore hoặc seed',
      );
    }

    // ── Bước 5: Nếu API thất bại, thử đọc trực tiếp từ Firestore questions (Admin SDK hoặc rules cho phép) ──
    if (!apiSuccess) {
      try {
        final qSnap = await db
            .collection(AppConstants.questionsCollection)
            .where('topicId', isEqualTo: effectiveTopicId)
            .where('isActive', isEqualTo: true)
            .get();
        if (qSnap.docs.isNotEmpty) {
          questions = qSnap.docs
              .map((d) => Question.fromJson({...d.data(), 'id': d.id}))
              .toList();
          debugPrint(
            '[QuizVM] Tải ${questions.length} câu thật từ Firestore questions thành công',
          );
        }
      } catch (e) {
        debugPrint(
          '[QuizVM] Firestore questions bị chặn hoặc lỗi ($e) — dùng 10 câu thật từ seed',
        );
      }
    }

    // ── Bước 6: Nếu vẫn chưa có câu hỏi, dùng 10 câu thật từ seed-data.json theo đúng topic ──
    if (questions.isEmpty) {
      questions = List.of(_getRealSeedQuestions(effectiveTopicId));
      debugPrint(
        '[QuizVM] Dùng ${questions.length} câu thật seed cho topic $effectiveTopicId',
      );
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
  /// Trợ giúp 1: 50/50 — ẩn 2 đáp án sai (30 xu). Mỗi câu chỉ dùng 1 lần.
  /// Đáp án đúng chỉ có ở server nên hỏi server lấy 2 đáp án sai.
  /// Trả về chuỗi lỗi nếu thất bại, null nếu thành công.
  Future<String?> useFiftyFifty() async {
    final q = currentQuestion;
    if (q == null) return 'Không có câu hỏi';
    if (hiddenOptions.containsKey(currentIndex))
      return 'Câu này đã dùng 50/50 rồi';
    if (userCoins < 30) return 'Không đủ xu (cần 30, còn $userCoins xu)';
    if (attemptId == null) {
      // Chế độ offline (câu mẫu): đáp án đúng có sẵn, tính tại chỗ.
      final wrong = [0, 1, 2, 3]
          .where((i) => i != q.correctIndex && answers[currentIndex] != i)
          .take(2)
          .toSet();
      hiddenOptions[currentIndex] = wrong;
      userCoins -= 30;
      notifyListeners();
      return null;
    }
    try {
      final data = await _api.post('/quiz/fifty-fifty', {
        'attemptId': attemptId,
        'questionId': q.id,
        'selectedIndex': answers[currentIndex],
      });
      final hide = (data['hiddenIndices'] as List? ?? [])
          .map((e) => (e as num).toInt())
          .toSet();
      hiddenOptions[currentIndex] = hide;
      userCoins -= 30;
      notifyListeners();
      return null;
    } catch (_) {
      return 'Không gọi được server, thử lại sau';
    }
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
    bool serverOk = false;
    try {
      if (attemptId != null) {
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final token = await user.getIdToken(true);
            _api.setToken(token);
          }
        } catch (_) {}
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
        serverOk = true;
      } else {
        _scoreLocally();
      }
    } catch (_) {
      _scoreLocally();
    }
    _submitting = false;

    // ── Cập nhật điểm và xu vào Firestore users/{uid} (chỉ khi server không lưu được) ──
    if (!serverOk) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && (score > 0 || coins > 0)) {
          FirebaseFirestore.instance
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .update({
                'score': FieldValue.increment(score),
                'coins': FieldValue.increment(coins),
                'weeklyScore': FieldValue.increment(score),
              });
        }
      } catch (e) {
        debugPrint('[QuizVM] Lỗi cập nhật điểm vào Firestore: $e');
      }
    }

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

  /// 30 câu hỏi thật theo đúng 3 chủ đề trong seed-data.json của đồ án.
  static List<Question> _getRealSeedQuestions(String topicId) {
    switch (topicId) {
      case 'topic_do_meo':
        return _seedDoMeo;
      case 'topic_giai_tri':
        return _seedGiaiTri;
      case 'topic_tong_hop':
      default:
        return _seedTongHop;
    }
  }

  // ── 1. Chủ đề: Kiến thức tổng hợp / Đời sống (10 câu thật từ seed-data.json) ──
  static const _seedTongHop = [
    Question(
      id: 'q_th_01',
      topicId: 'topic_tong_hop',
      content: 'Nước nào có diện tích lớn nhất thế giới?',
      options: ['Nga', 'Canada', 'Mỹ', 'Trung Quốc'],
      correctIndex: 0,
      level: 'easy',
      explanation: 'Nga có diện tích hơn 17 triệu km², lớn nhất thế giới.',
    ),
    Question(
      id: 'q_th_02',
      topicId: 'topic_tong_hop',
      content: 'Hành tinh nào gần Mặt Trời nhất?',
      options: ['Sao Kim', 'Sao Thủy', 'Sao Hỏa', 'Trái Đất'],
      correctIndex: 1,
      level: 'easy',
      explanation: 'Sao Thủy (Mercury) là hành tinh gần Mặt Trời nhất.',
    ),
    Question(
      id: 'q_th_03',
      topicId: 'topic_tong_hop',
      content: 'Một giờ có bao nhiêu phút?',
      options: ['50 phút', '60 phút', '70 phút', '100 phút'],
      correctIndex: 1,
      level: 'easy',
      explanation: 'Theo quy ước quốc tế 1 giờ = 60 phút.',
    ),
    Question(
      id: 'q_th_04',
      topicId: 'topic_tong_hop',
      content: 'Con vật nào được gọi là “chúa tể sơn lâm”?',
      options: ['Hổ', 'Sư tử', 'Voi', 'Báo'],
      correctIndex: 0,
      level: 'easy',
      explanation:
          'Trong văn hóa phương Đông, hổ thường được gọi là chúa sơn lâm.',
    ),
    Question(
      id: 'q_th_05',
      topicId: 'topic_tong_hop',
      content: 'Công thức hóa học của nước là gì?',
      options: ['CO₂', 'H₂O', 'O₂', 'NaCl'],
      correctIndex: 1,
      level: 'easy',
      explanation: 'Nước gồm 2 nguyên tử Hydro và 1 nguyên tử Oxy: H₂O.',
    ),
    Question(
      id: 'q_th_06',
      topicId: 'topic_tong_hop',
      content: 'Thủ đô của Nhật Bản là thành phố nào?',
      options: ['Kyoto', 'Osaka', 'Tokyo', 'Hiroshima'],
      correctIndex: 2,
      level: 'medium',
      explanation: 'Tokyo là thủ đô hiện tại của Nhật Bản từ năm 1868.',
    ),
    Question(
      id: 'q_th_07',
      topicId: 'topic_tong_hop',
      content: 'Ai là tác giả bức tranh Mona Lisa?',
      options: [
        'Vincent van Gogh',
        'Pablo Picasso',
        'Leonardo da Vinci',
        'Claude Monet',
      ],
      correctIndex: 2,
      level: 'medium',
      explanation: 'Leonardo da Vinci vẽ bức Mona Lisa vào đầu thế kỷ 16.',
    ),
    Question(
      id: 'q_th_08',
      topicId: 'topic_tong_hop',
      content: 'Số nguyên tố nhỏ nhất là số nào?',
      options: ['0', '1', '2', '3'],
      correctIndex: 2,
      level: 'medium',
      explanation: 'Số 2 là số nguyên tố chẵn duy nhất và nhỏ nhất.',
    ),
    Question(
      id: 'q_th_09',
      topicId: 'topic_tong_hop',
      content: 'Nguyên tố nào có ký hiệu hóa học là Au?',
      options: ['Bạc', 'Đồng', 'Vàng', 'Nhôm'],
      correctIndex: 2,
      level: 'hard',
      explanation: 'Au bắt nguồn từ tiếng Latin "Aurum", nghĩa là vàng.',
    ),
    Question(
      id: 'q_th_10',
      topicId: 'topic_tong_hop',
      content: 'Con người lần đầu đặt chân lên Mặt Trăng vào năm nào?',
      options: ['1965', '1969', '1972', '1975'],
      correctIndex: 1,
      level: 'hard',
      explanation: 'Tàu Apollo 11 hạ cánh xuống Mặt Trăng ngày 20/7/1969.',
    ),
  ];

  // ── 2. Chủ đề: Đố dân gian & Câu đố mẹo (10 câu thật từ seed-data.json) ──
  static const _seedDoMeo = [
    Question(
      id: 'q_dm_01',
      topicId: 'topic_do_meo',
      content: 'Con gì đập thì sống, không đập thì chết?',
      options: ['Con tim', 'Con gà', 'Con cá', 'Con chó'],
      correctIndex: 0,
      level: 'easy',
      explanation: 'Tim phải đập thì người mới sống.',
    ),
    Question(
      id: 'q_dm_02',
      topicId: 'topic_do_meo',
      content: 'Cái gì có răng mà không cắn được ai?',
      options: ['Cái lược', 'Cái búa', 'Cái kéo', 'Con dao'],
      correctIndex: 0,
      level: 'easy',
      explanation: 'Lược có răng nhưng chỉ để chải tóc.',
    ),
    Question(
      id: 'q_dm_03',
      topicId: 'topic_do_meo',
      content: 'Cái gì càng kéo càng ngắn?',
      options: ['Điếu thuốc', 'Sợi dây', 'Cái thước', 'Cây nến'],
      correctIndex: 0,
      level: 'easy',
      explanation: 'Điếu thuốc càng hút (kéo hơi) càng ngắn lại.',
    ),
    Question(
      id: 'q_dm_04',
      topicId: 'topic_do_meo',
      content: 'Cái gì có cổ mà không có đầu?',
      options: ['Cái chai', 'Cái áo', 'Cái ly', 'Cái bát'],
      correctIndex: 0,
      level: 'easy',
      explanation: 'Chai có cổ chai nhưng không có đầu.',
    ),
    Question(
      id: 'q_dm_05',
      topicId: 'topic_do_meo',
      content: 'Tôi có thành phố nhưng không có nhà, có rừng nhưng không có cây, có sông nhưng không có nước. Tôi là gì?',
      options: ['Bản đồ', 'Bức tranh', 'Quyển sách', 'Quả địa cầu'],
      correctIndex: 0,
      level: 'medium',
      explanation: 'Bản đồ vẽ thành phố, rừng, sông nhưng chúng không có thật.',
    ),
    Question(
      id: 'q_dm_06',
      topicId: 'topic_do_meo',
      content: 'Cái gì cho đi càng nhiều thì càng còn nhiều?',
      options: ['Kiến thức', 'Tiền bạc', 'Đồ ăn', 'Quần áo'],
      correctIndex: 0,
      level: 'medium',
      explanation:
          'Kiến thức chia sẻ cho người khác vẫn còn nguyên trong đầu mình.',
    ),
    Question(
      id: 'q_dm_07',
      topicId: 'topic_do_meo',
      content: 'Cái gì có chân mà không đi được?',
      options: ['Cái bàn', 'Con chó', 'Con người', 'Chiếc xe'],
      correctIndex: 0,
      level: 'medium',
      explanation: 'Cái bàn, cái ghế có chân nhưng đứng yên một chỗ.',
    ),
    Question(
      id: 'q_dm_08',
      topicId: 'topic_do_meo',
      content: 'Cái gì của bạn nhưng người khác dùng nhiều hơn bạn?',
      options: [
        'Tên của bạn',
        'Điện thoại của bạn',
        'Xe của bạn',
        'Quần áo của bạn',
      ],
      correctIndex: 0,
      level: 'medium',
      explanation: 'Tên của bạn chủ yếu do người khác gọi.',
    ),
    Question(
      id: 'q_dm_09',
      topicId: 'topic_do_meo',
      content:
          'Một người đàn ông đẩy xe vào khách sạn rồi mất hết tài sản. Vì sao?',
      options: ['Đang chơi cờ tỷ phú', 'Bị cướp', 'Bị lừa đảo', 'Đánh bạc'],
      correctIndex: 0,
      level: 'hard',
      explanation: 'Trong trò chơi cờ tỷ phú (Monopoly), đi vào ô có khách sạn của người khác là mất tiền.',
    ),
    Question(
      id: 'q_dm_10',
      topicId: 'topic_do_meo',
      content: 'Cái gì đi khắp thế giới mà vẫn ở nguyên một góc?',
      options: ['Con tem', 'Bưu thiếp', 'La bàn', 'Bản đồ'],
      correctIndex: 0,
      level: 'hard',
      explanation: 'Con tem dán ở góc bức thư đi khắp thế giới.',
    ),
  ];

  // ── 3. Chủ đề: Giải trí – Âm nhạc – Phim ảnh (10 câu thật từ seed-data.json) ──
  static const _seedGiaiTri = [
    Question(
      id: 'q_gt_01',
      topicId: 'topic_giai_tri',
      content: 'Nhân vật hoạt hình nào có đôi tai tròn màu đen?',
      options: ['Chuột Mickey', 'Vịt Donald', 'Gấu Pooh', 'Chó Snoopy'],
      correctIndex: 0,
      level: 'easy',
      explanation:
          'Mickey Mouse là biểu tượng nổi tiếng của Disney với đôi tai tròn.',
    ),
    Question(
      id: 'q_gt_02',
      topicId: 'topic_giai_tri',
      content: 'Ca sĩ nào được mệnh danh là “Ông hoàng nhạc Việt”?',
      options: ['Đàm Vĩnh Hưng', 'Sơn Tùng M-TP', 'Tuấn Hưng', 'Đan Trường'],
      correctIndex: 0,
      level: 'easy',
      explanation: 'Biệt danh truyền thông thường dành cho Đàm Vĩnh Hưng.',
    ),
    Question(
      id: 'q_gt_03',
      topicId: 'topic_giai_tri',
      content: 'Bài Quốc ca của Việt Nam có tên là gì?',
      options: [
        'Tiến quân ca',
        'Như có Bác Hồ trong ngày vui đại thắng',
        'Hát mãi khúc quân hành',
        'Đoàn quân Việt Nam',
      ],
      correctIndex: 0,
      level: 'easy',
      explanation: '“Tiến quân ca” được nhạc sĩ Văn Cao sáng tác năm 1944.',
    ),
    Question(
      id: 'q_gt_04',
      topicId: 'topic_giai_tri',
      content: 'Bộ phim nào có nhân vật Tôn Ngộ Không?',
      options: ['Tây Du Ký', 'Tam Quốc Diễn Nghĩa', 'Thủy Hử', 'Hồng Lâu Mộng'],
      correctIndex: 0,
      level: 'easy',
      explanation: 'Tôn Ngộ Không là nhân vật chính trong tiểu thuyết và phim Tây Du Ký.',
    ),
    Question(
      id: 'q_gt_05',
      topicId: 'topic_giai_tri',
      content: 'Ai là đạo diễn phim “Tôi thấy hoa vàng trên cỏ xanh”?',
      options: [
        'Victor Vũ',
        'Trấn Thành',
        'Charlie Nguyễn',
        'Nguyễn Quang Dũng',
      ],
      correctIndex: 0,
      level: 'medium',
      explanation: 'Phim chuyển thể từ truyện của Nguyễn Nhật Ánh do Victor Vũ đạo diễn (2015).',
    ),
    Question(
      id: 'q_gt_06',
      topicId: 'topic_giai_tri',
      content: 'Nhạc cụ nào có 88 phím?',
      options: ['Piano', 'Organ', 'Guitar', 'Violon'],
      correctIndex: 0,
      level: 'medium',
      explanation: 'Đàn piano tiêu chuẩn hiện đại có 52 phím trắng và 36 phím đen (tổng 88).',
    ),
    Question(
      id: 'q_gt_07',
      topicId: 'topic_giai_tri',
      content: 'Nhân vật Người Sắt (Iron Man) xuất hiện trong bộ phim nào?',
      options: ['Iron Man', 'Batman', 'Spider-Man', 'Superman'],
      correctIndex: 0,
      level: 'medium',
      explanation: 'Iron Man (Tony Stark) là siêu anh hùng của vũ trụ điện ảnh Marvel (MCU).',
    ),
    Question(
      id: 'q_gt_08',
      topicId: 'topic_giai_tri',
      content: 'Ca khúc “Nối vòng tay lớn” là của nhạc sĩ nào?',
      options: ['Trịnh Công Sơn', 'Văn Cao', 'Phạm Tuyên', 'Hoàng Vân'],
      correctIndex: 0,
      level: 'medium',
      explanation: 'Nhạc sĩ Trịnh Công Sơn sáng tác bài này năm 1968.',
    ),
    Question(
      id: 'q_gt_09',
      topicId: 'topic_giai_tri',
      content: 'Giải Oscar được trao lần đầu tiên vào năm nào?',
      options: ['1929', '1935', '1940', '1950'],
      correctIndex: 0,
      level: 'hard',
      explanation: 'Lễ trao giải Oscar đầu tiên diễn ra ngày 16/5/1929 tại Hollywood Roosevelt Hotel.',
    ),
    Question(
      id: 'q_gt_10',
      topicId: 'topic_giai_tri',
      content: 'Bộ phim nào có doanh thu phòng vé cao nhất mọi thời đại?',
      options: ['Avatar', 'Avengers: Endgame', 'Titanic', 'Star Wars'],
      correctIndex: 0,
      level: 'hard',
      explanation: 'Avatar (2009) của đạo diễn James Cameron hiện giữ kỷ lục doanh thu hơn 2,9 tỷ USD.',
    ),
  ];
}
