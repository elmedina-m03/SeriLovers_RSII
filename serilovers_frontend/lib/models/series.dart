/// Model representing a TV Series
class Series {
  final int id;
  final String title;
  final String? description;
  final DateTime releaseDate;
  final double rating;
  final List<Genre> genres;
  final List<Actor> actors;
  final int ratingsCount;
  final int watchlistsCount;

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
  });

  /// Creates a Series instance from JSON
  factory Series.fromJson(Map<String, dynamic> json) {
    return Series(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      rating: (json['rating'] as num).toDouble(),
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => Genre.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      actors: (json['actors'] as List<dynamic>?)
              ?.map((a) => Actor.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      ratingsCount: json['ratingsCount'] as int? ?? 0,
      watchlistsCount: json['watchlistsCount'] as int? ?? 0,
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
      'genres': genres.map((g) => g.toJson()).toList(),
      'actors': actors.map((a) => a.toJson()).toList(),
      'ratingsCount': ratingsCount,
      'watchlistsCount': watchlistsCount,
    };
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

  Actor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
  });

  factory Actor.fromJson(Map<String, dynamic> json) {
    return Actor(
      id: json['id'] as int,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      fullName: json['fullName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
    };
  }
}

