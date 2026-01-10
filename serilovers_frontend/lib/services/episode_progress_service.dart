import '../models/episode_progress.dart';
import 'api_service.dart';

class EpisodeProgressService {
  final ApiService _apiService;

  EpisodeProgressService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Mark an episode as watched
  Future<EpisodeProgress> markEpisodeWatched(
    int episodeId, {
    bool isCompleted = true,
    String? token,
  }) async {
    final response = await _apiService.post(
      '/EpisodeProgress',
      {
        'episodeId': episodeId,
        'isCompleted': isCompleted,
      },
      token: token,
    );

    if (response is Map<String, dynamic>) {
      return EpisodeProgress.fromJson(response);
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Get progress for a specific series
  Future<SeriesProgress> getSeriesProgress(
    int seriesId, {
    String? token,
  }) async {
    final response = await _apiService.get(
      '/EpisodeProgress/series/$seriesId',
      token: token,
    );

    // Handle null or empty response (API returns 200 OK but no data)
    if (response == null) {
      // Return empty progress object with default values
      return SeriesProgress(
        seriesId: seriesId,
        totalEpisodes: 0,
        watchedEpisodes: 0,
        currentEpisodeNumber: 0,
        currentSeasonNumber: 0,
        progressPercentage: 0.0,
      );
    }

    if (response is Map<String, dynamic>) {
      // Handle empty map (API returns 200 OK with empty object)
      if (response.isEmpty) {
        return SeriesProgress(
          seriesId: seriesId,
          totalEpisodes: 0,
          watchedEpisodes: 0,
          currentEpisodeNumber: 0,
          currentSeasonNumber: 0,
          progressPercentage: 0.0,
        );
      }
      
      // Try to parse the response, but handle missing fields gracefully
      try {
        return SeriesProgress.fromJson(response);
      } catch (e) {
        // If JSON parsing fails (e.g., missing required fields), return empty progress
        // This handles cases where API returns 200 OK but with incomplete data
        return SeriesProgress(
          seriesId: seriesId,
          totalEpisodes: response['totalEpisodes'] as int? ?? 0,
          watchedEpisodes: response['watchedEpisodes'] as int? ?? 0,
          currentEpisodeNumber: response['currentEpisodeNumber'] as int? ?? 0,
          currentSeasonNumber: response['currentSeasonNumber'] as int? ?? 0,
          progressPercentage: (response['progressPercentage'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } else {
      throw Exception('Invalid response format: expected Map, got ${response.runtimeType}');
    }
  }

  /// Get all watched episodes for current user
  Future<List<EpisodeProgress>> getUserProgress({String? token}) async {
    final response = await _apiService.get(
      '/EpisodeProgress',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => EpisodeProgress.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }

  /// Remove episode progress (mark as unwatched)
  Future<void> removeProgress(int episodeId, {String? token}) async {
    await _apiService.delete(
      '/EpisodeProgress/$episodeId',
      token: token,
    );
  }

  /// Get the next episode to watch for a series
  Future<Map<String, dynamic>?> getNextEpisode(int seriesId, {String? token}) async {
    try {
      final response = await _apiService.get(
        '/EpisodeProgress/series/$seriesId/next',
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the last watched episode for a series
  Future<Map<String, dynamic>?> getLastWatchedEpisode(int seriesId, {String? token}) async {
    try {
      final response = await _apiService.get(
        '/EpisodeProgress/series/$seriesId/last',
        token: token,
      );

      if (response is Map<String, dynamic>) {
        return response;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all series with their watching status for current user
  /// Returns all series that the user has watched at least one episode of, regardless of watchlist membership
  Future<List<Map<String, dynamic>>> getUserSeriesWithStatus({String? token}) async {
    final response = await _apiService.get(
      '/EpisodeProgress/user/status',
      token: token,
    );

    if (response is List) {
      return response
          .map((item) => item as Map<String, dynamic>)
          .toList();
    } else {
      throw Exception('Invalid response format');
    }
  }
}

