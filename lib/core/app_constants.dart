class AppConstants {
  AppConstants._();

  // 1. Thông tin ứng dụng (Wireframe 01)
  static const String appName = 'Đố Vui Ai Thưởng';

  // 2. Tên đầy đủ 16 Collections trên Cloud Firestore (Mục 3.1 & 3.2)
  static const String usersCollection = 'users';
  static const String topicsCollection = 'topics';
  static const String questionsCollection = 'questions';
  static const String quizSetsCollection = 'quiz_sets';
  static const String quizHistoriesCollection = 'quiz_histories';
  static const String reviewsCollection = 'reviews';
  static const String favoritesCollection = 'favorites';
  static const String itemsCollection = 'items';
  static const String userItemsCollection = 'user_items';
  static const String transactionsCollection = 'transactions';
  static const String friendsCollection = 'friends';
  static const String roomsCollection = 'rooms';
  static const String matchHistoriesCollection = 'match_histories';
  static const String matchQueuesCollection = 'match_queues';
  static const String reportsCollection = 'reports';
  static const String notificationsCollection = 'notifications';

  // 3. Quy ước khởi tạo tài khoản mới (Mục 2.3)
  static const int initialCoins = 100;
  static const int initialScore = 0;
  static const int initialWeeklyScore = 0;
  static const int userCodeLength = 6;

  // 4. Phân quyền & Trạng thái tài khoản (Mục 2.1 & 3.2)
  static const String roleUser = 'user';
  static const String roleAdmin = 'admin';
  static const String statusActive = 'active';
  static const String statusLocked = 'locked';

  // 5. Quy tắc Quyền trợ giúp & Thi đấu 1vs1 (Mục 2.3)
  static const int lifeline5050Cost = 30;
  static const int lifelineAddTimeCost = 20;
  static const int lifelineAddTimeSeconds = 15;
  static const int lifelineSkipCost = 30;
  static const int pvpTotalQuestions = 10;
  static const int pvpSecondsPerQuestion = 15;
}