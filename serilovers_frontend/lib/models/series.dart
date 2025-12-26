import 'season.dart';

/// Model representing a TV Series
class Series {
  final int id;
  final String title;
  final String? description;
  final DateTime releaseDate;
  final double rating;
  final List<String> genres;
  final List<Actor> actors;
  final int ratingsCount;
  final int watchlistsCount;
  final String? imageUrl;
  final List<Season> seasons;
  final int? _totalEpisodesFromBackend; // Total episodes count from backend (if available)

  Series({
    required this.id,
    required this.title,
    this.description,
    required this.releaseDate,
    required this.rating,
    required this.genres,
    required this.actors,
    required this.ratingsCount,
    required this.watchlistsCount,
    this.imageUrl,
    this.seasons = const [],
    int? totalEpisodesFromBackend,
  }) : _totalEpisodesFromBackend = totalEpisodesFromBackend;


  /// Creates a Series instance from JSON
  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      rating: (json['rating'] as num).toDouble(),
      genres: (json['genres'] as List?)?.map((e) => e.toString()).toList() ?? [],
      actors: (json['actors'] as List<dynamic>?)
              ?.map((a) => Actor.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      ratingsCount: json['ratingsCount'] as int? ?? 0,
      watchlistsCount: json['watchlistsCount'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String?,
      totalEpisodesFromBackend: json['totalEpisodes'] as int?,
      seasons: (json['seasons'] as List<dynamic>?)
              ?.map((s) => Season.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Converts Series instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'releaseDate': releaseDate.toIso8601String(),
      'rating': rating,
      'genres': genres,
      'actors': actors.map((a) => a.toJson()).toList(),
      'ratingsCount': ratingsCount,
      'watchlistsCount': watchlistsCount,
      'imageUrl': imageUrl,
      'seasons': seasons.map((s) => s.toJson()).toList(),
    };
  }

  /// Get total number of episodes across all seasons
  /// Uses backend totalEpisodes if available, otherwise calculates from seasons
  /// Returns 0 if no seasons or episodes exist
  int get totalEpisodes {
    // If backend provided totalEpisodes, use it (more efficient and accurate)
    if (_totalEpisodesFromBackend != null && _totalEpisodesFromBackend! >= 0) {
      return _totalEpisodesFromBackend!;
    }
    // Otherwise calculate from seasons (fallback for backward compatibility or when seasons are loaded)
    if (seasons.isEmpty) return 0;
    return seasons.fold(0, (sum, season) => sum + (season.episodes.length));
  }

  /// Get total number of seasons
  int get totalSeasons {
    return seasons.length;
  }
}

/// Model representing a Genre
class Genre {
  final int id;
  final String name;

  Genre({
    required this.id,
    required this.name,
  });

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Model representing an Actor
class Actor {
  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final DateTime? dateOfBirth;
  final int? age;
  final int seriesCount;
  final String? imageUrl;

  Actor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.dateOfBirth,
    this.age,
    this.seriesCount = 0,
    this.imageUrl,
  });

  factory Actor.fromJson(Map<String, dynamic> json) {
    return Actor(
      id: json['id'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      fullName: json['fullName'] as String? ?? '${json['firstName']} ${json['lastName']}',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      age: json['age'] as int?,
      seriesCount: (json['series'] as List<dynamic>?)?.length ?? 
                   (json['seriesCount'] as int?) ?? 0,
      imageUrl: json['imageUrl'] as String?,
    );
  }
  
  /// Calculate age from date of birth if not provided
  int? get calculatedAge {
    if (age != null) return age;
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int calculated = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      calculated--;
    }
    return calculated;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'seriesCount': seriesCount,
      'imageUrl': imageUrl,
    };
  }
}

