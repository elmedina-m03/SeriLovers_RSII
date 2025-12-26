/// Models for admin statistics matching backend DTOs

/// Main statistics DTO
class AdminStatistics {
  final Totals totals;
  final List<GenreDistribution> genreDistribution;
  final List<MonthlyWatching> monthlyWatching;
  final List<TopSeries> topSeries;

  AdminStatistics({
    required this.totals,
    required this.genreDistribution,
    required this.monthlyWatching,
    required this.topSeries,
  });

  factory AdminStatistics.fromJson(Map<String, dynamic> json) {
    return AdminStatistics(
      totals: Totals.fromJson(json['totals'] as Map<String, dynamic>? ?? {}),
      genreDistribution: (json['genreDistribution'] as List<dynamic>?)
              ?.map((e) => GenreDistribution.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      monthlyWatching: (json['monthlyWatching'] as List<dynamic>?)
              ?.map((e) => MonthlyWatching.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      topSeries: (json['topSeries'] as List<dynamic>?)
              ?.map((e) => TopSeries.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totals': totals.toJson(),
      'genreDistribution': genreDistribution.map((e) => e.toJson()).toList(),
      'monthlyWatching': monthlyWatching.map((e) => e.toJson()).toList(),
      'topSeries': topSeries.map((e) => e.toJson()).toList(),
    };
  }
}

/// Totals statistics
class Totals {
  final int users;
  final int series;
  final int actors;
  final int watchlistItems;

  Totals({
    required this.users,
    required this.series,
    required this.actors,
    required this.watchlistItems,
  });

  factory Totals.fromJson(Map<String, dynamic> json) {
    return Totals(
      users: (json['users'] as num?)?.toInt() ?? 0,
      series: (json['series'] as num?)?.toInt() ?? 0,
      actors: (json['actors'] as num?)?.toInt() ?? 0,
      watchlistItems: (json['watchlistItems'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users': users,
      'series': series,
      'actors': actors,
      'watchlistItems': watchlistItems,
    };
  }
}

/// Genre distribution statistics
class GenreDistribution {
  final String genre;
  final double percentage;

  GenreDistribution({
    required this.genre,
    required this.percentage,
  });

  factory GenreDistribution.fromJson(Map<String, dynamic> json) {
    return GenreDistribution(
      genre: json['genre'] as String? ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'genre': genre,
      'percentage': percentage,
    };
  }
}

/// Monthly watching statistics
class MonthlyWatching {
  final String month; // Format: "YYYY-MM"
  final int views;

  MonthlyWatching({
    required this.month,
    required this.views,
  });

  factory MonthlyWatching.fromJson(Map<String, dynamic> json) {
    return MonthlyWatching(
      month: json['month'] as String? ?? '',
      views: (json['views'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'views': views,
    };
  }

  /// Get display label (e.g., "12/25" for December 2025)
  String get monthYearLabel {
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final monthNum = int.tryParse(parts[1]);
        if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
          // Format as MM/YY (e.g., "12/25" for December 2025)
          final yearShort = year.length >= 2 ? year.substring(year.length - 2) : year;
          return '${monthNum.toString().padLeft(2, '0')}/$yearShort';
        }
      }
    } catch (e) {
      // Fallback
    }
    return month;
  }
}

/// Top rated series statistics
class TopSeries {
  final int id;
  final String title;
  final double avgRating;
  final int views;
  final String? imageUrl;

  TopSeries({
    required this.id,
    required this.title,
    required this.avgRating,
    required this.views,
    this.imageUrl,
  });

  factory TopSeries.fromJson(Map<String, dynamic> json) {
    return TopSeries(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? 'Unknown',
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      views: (json['views'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'avgRating': avgRating,
      'views': views,
      'imageUrl': imageUrl,
    };
  }
}
