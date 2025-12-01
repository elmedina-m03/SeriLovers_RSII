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

    if (response is Map<String, dynamic>) {
      return SeriesProgress.fromJson(response);
    } else {
      throw Exception('Invalid response format');
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
}

