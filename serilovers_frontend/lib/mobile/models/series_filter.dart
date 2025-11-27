import '../../models/series.dart';

/// Represents filter selections used across mobile screens.
class SeriesFilter {
  final Genre? genre;
  final int? startYear;
  final int? endYear;

  const SeriesFilter({
    this.genre,
    this.startYear,
    this.endYear,
  });

  bool get isEmpty =>
      genre == null &&
      startYear == null &&
      endYear == null;

  SeriesFilter copyWith({
    Genre? genre,
    int? startYear,
    int? endYear,
  }) {
    return SeriesFilter(
      genre: genre ?? this.genre,
      startYear: startYear ?? this.startYear,
      endYear: endYear ?? this.endYear,
    );
  }
}

