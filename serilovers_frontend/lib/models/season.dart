/// Model representing a Season
class Season {
  final int id;
  final int seasonNumber;
  final String title;
  final String? description;
  final DateTime? releaseDate;
  final List<Episode> episodes;

  Season({
    required this.id,
    required this.seasonNumber,
    required this.title,
    this.description,
    this.releaseDate,
    required this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'] as int,
      seasonNumber: json['seasonNumber'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'] as String)
          : null,
      episodes: (json['episodes'] as List<dynamic>?)
              ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seasonNumber': seasonNumber,
      'title': title,
      'description': description,
      'releaseDate': releaseDate?.toIso8601String(),
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}

/// Model representing an Episode
class Episode {
  final int id;
  final int episodeNumber;
  final String title;
  final String? description;
  final DateTime? airDate;
  final int? durationMinutes;
  final double? rating;

  Episode({
    required this.id,
    required this.episodeNumber,
    required this.title,
    this.description,
    this.airDate,
    this.durationMinutes,
    this.rating,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] as int,
      episodeNumber: json['episodeNumber'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      airDate: json['airDate'] != null
          ? DateTime.parse(json['airDate'] as String)
          : null,
      durationMinutes: json['durationMinutes'] as int?,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'episodeNumber': episodeNumber,
      'title': title,
      'description': description,
      'airDate': airDate?.toIso8601String(),
      'durationMinutes': durationMinutes,
      'rating': rating,
    };
  }
}

