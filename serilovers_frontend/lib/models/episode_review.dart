class EpisodeReview {
  final int id;
  final int userId;
  final String? userName;
  final String? userAvatarUrl;
  final int episodeId;
  final String? episodeTitle;
  final int episodeNumber;
  final int seasonId;
  final int seasonNumber;
  final int seriesId;
  final String? seriesTitle;
  final int rating; // 1-5 stars
  final String? reviewText;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EpisodeReview({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.episodeId,
    this.episodeTitle,
    required this.episodeNumber,
    required this.seasonId,
    required this.seasonNumber,
    required this.seriesId,
    this.seriesTitle,
    required this.rating,
    this.reviewText,
    required this.createdAt,
    this.updatedAt,
  });

  factory EpisodeReview.fromJson(Map<String, dynamic> json) {
    return EpisodeReview(
      id: json['id'] as int,
      userId: json['userId'] as int,
      userName: json['userName'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      episodeId: json['episodeId'] as int,
      episodeTitle: json['episodeTitle'] as String?,
      episodeNumber: json['episodeNumber'] as int,
      seasonId: json['seasonId'] as int,
      seasonNumber: json['seasonNumber'] as int,
      seriesId: json['seriesId'] as int,
      seriesTitle: json['seriesTitle'] as String?,
      rating: json['rating'] as int,
      reviewText: json['reviewText'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'episodeId': episodeId,
      'episodeTitle': episodeTitle,
      'episodeNumber': episodeNumber,
      'seasonId': seasonId,
      'seasonNumber': seasonNumber,
      'seriesId': seriesId,
      'seriesTitle': seriesTitle,
      'rating': rating,
      'reviewText': reviewText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

