class EpisodeProgress {
  final int id;
  final int userId;
  final String? userName;
  final int episodeId;
  final String? episodeTitle;
  final int episodeNumber;
  final int seasonId;
  final int seasonNumber;
  final int seriesId;
  final String? seriesTitle;
  final DateTime watchedAt;
  final bool isCompleted;

  EpisodeProgress({
    required this.id,
    required this.userId,
    this.userName,
    required this.episodeId,
    this.episodeTitle,
    required this.episodeNumber,
    required this.seasonId,
    required this.seasonNumber,
    required this.seriesId,
    this.seriesTitle,
    required this.watchedAt,
    required this.isCompleted,
  });

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeProgress(
      id: json['id'] as int,
      userId: json['userId'] as int,
      userName: json['userName'] as String?,
      episodeId: json['episodeId'] as int,
      episodeTitle: json['episodeTitle'] as String?,
      episodeNumber: json['episodeNumber'] as int,
      seasonId: json['seasonId'] as int,
      seasonNumber: json['seasonNumber'] as int,
      seriesId: json['seriesId'] as int,
      seriesTitle: json['seriesTitle'] as String?,
      watchedAt: DateTime.parse(json['watchedAt'] as String),
      isCompleted: json['isCompleted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'episodeId': episodeId,
      'episodeTitle': episodeTitle,
      'episodeNumber': episodeNumber,
      'seasonId': seasonId,
      'seasonNumber': seasonNumber,
      'seriesId': seriesId,
      'seriesTitle': seriesTitle,
      'watchedAt': watchedAt.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }
}

class SeriesProgress {
  final int seriesId;
  final String? seriesTitle;
  final int totalEpisodes;
  final int watchedEpisodes;
  final int currentEpisodeNumber;
  final int currentSeasonNumber;
  final double progressPercentage;

  SeriesProgress({
    required this.seriesId,
    this.seriesTitle,
    required this.totalEpisodes,
    required this.watchedEpisodes,
    required this.currentEpisodeNumber,
    required this.currentSeasonNumber,
    required this.progressPercentage,
  });

  factory SeriesProgress.fromJson(Map<String, dynamic> json) {
    return SeriesProgress(
      seriesId: json['seriesId'] as int,
      seriesTitle: json['seriesTitle'] as String?,
      totalEpisodes: json['totalEpisodes'] as int,
      watchedEpisodes: json['watchedEpisodes'] as int,
      currentEpisodeNumber: json['currentEpisodeNumber'] as int,
      currentSeasonNumber: json['currentSeasonNumber'] as int,
      progressPercentage: (json['progressPercentage'] as num).toDouble(),
    );
  }
}

