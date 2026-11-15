// Model Đánh giá bộ đề — khớp collection `reviews` trong Firestore.
// File này TV1 An giữ (thẻ [Mục 12-13] Chi tiết Bộ đề & Xem đánh giá).
class Review {
  final String id;
  final String quizSetId;
  final String userName;
  final int rating; // 1..5 sao
  final String comment;
  final String createdAt;

  const Review({
    required this.id,
    required this.quizSetId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String? ?? '',
      quizSetId: json['quizSetId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Người chơi',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}
