/// Model representing genre distribution statistics
class GenreDistribution {
  final String genreName;
  final int count;

  GenreDistribution({
    required this.genreName,
    required this.count,
  });

  /// Creates a GenreDistribution instance from JSON
  factory GenreDistribution.fromJson(Map<String, dynamic> json) {
    return GenreDistribution(
      genreName: json['genre'] as String,
      count: json['count'] as int,
    );
  }

  /// Converts GenreDistribution instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'genre': genreName,
      'count': count,
    };
  }
}

