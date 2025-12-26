import 'series.dart';

class SeriesRecommendation {
  final int id;
  final String title;
  final String? imageUrl;
  final List<String> genres;
  final double averageRating;
  final double similarityScore;
  final String? reason;

  SeriesRecommendation({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.genres,
    required this.averageRating,
    required this.similarityScore,
    this.reason,
  });

  factory SeriesRecommendation.fromJson(Map<String, dynamic> json) {
    return SeriesRecommendation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Unknown',
      imageUrl: json['imageUrl'] as String?,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g.toString())
              .toList() ??
          [],
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      similarityScore: (json['similarityScore'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'genres': genres,
      'averageRating': averageRating,
      'similarityScore': similarityScore,
      'reason': reason,
    };
  }

  /// Convert to Series model for compatibility
  Series toSeries() {
    return Series(
      id: id,
      title: title,
      description: '',
      releaseDate: DateTime.now(),
      rating: averageRating,
      imageUrl: imageUrl,
      seasons: [],
      genres: genres,
      actors: [],
      ratingsCount: 0,
      watchlistsCount: 0,
    );
  }
}

