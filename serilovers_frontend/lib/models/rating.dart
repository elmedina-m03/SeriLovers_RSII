/// Model representing a Series Rating/Review
class Rating {
  final int id;
  final int userId;
  final int seriesId;
  final int score; // 1-10
  final String? comment;
  final DateTime createdAt;
  final String? userName; // Optional, from API response

  Rating({
    required this.id,
    required this.userId,
    required this.seriesId,
    required this.score,
    this.comment,
    required this.createdAt,
    this.userName,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] as int,
      userId: json['userId'] as int,
      seriesId: json['seriesId'] as int,
      score: json['score'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      userName: json['userName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'seriesId': seriesId,
      'score': score,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'userName': userName,
    };
  }

  /// Convert score (1-10) to stars (1-5)
  int get starRating {
    // Convert 1-10 scale to 1-5 stars
    // 1-2 = 1 star, 3-4 = 2 stars, 5-6 = 3 stars, 7-8 = 4 stars, 9-10 = 5 stars
    if (score <= 2) return 1;
    if (score <= 4) return 2;
    if (score <= 6) return 3;
    if (score <= 8) return 4;
    return 5;
  }
}

