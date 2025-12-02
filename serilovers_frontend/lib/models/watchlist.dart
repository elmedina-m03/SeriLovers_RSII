class Watchlist {
  final int id;
  final String name;
  final String coverUrl;
  final int totalSeries;
  final DateTime createdAt;

  const Watchlist({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.totalSeries,
    required this.createdAt,
  });

  factory Watchlist.fromJson(Map<String, dynamic> json) {
    return Watchlist(
      id: json['id'] as int,
      name: json['name'] as String,
      coverUrl: (json['coverUrl'] ?? json['cover_url'] ?? '') as String,
      totalSeries: (json['totalSeries'] ?? json['total_series'] ?? json['seriesCount'] ?? json['series_count'] ?? 0) as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'coverUrl': coverUrl,
      'totalSeries': totalSeries,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Watchlist &&
        other.id == id &&
        other.name == name &&
        other.coverUrl == coverUrl &&
        other.totalSeries == totalSeries &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      coverUrl.hashCode ^
      totalSeries.hashCode ^
      createdAt.hashCode;
}


