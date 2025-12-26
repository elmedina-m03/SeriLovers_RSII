import 'package:flutter/foundation.dart';
import '../models/episode_progress.dart';
import '../services/episode_progress_service.dart';
import 'auth_provider.dart';

class EpisodeProgressProvider extends ChangeNotifier {
  final EpisodeProgressService _service;
  AuthProvider? _authProvider;

  EpisodeProgressProvider({
    required EpisodeProgressService service,
    AuthProvider? authProvider,
  })  : _service = service,
        _authProvider = authProvider;

  void updateAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  bool loading = false;
  String? error;

  // Cache for series progress
  final Map<int, SeriesProgress> _seriesProgressCache = {};

  SeriesProgress? getSeriesProgress(int seriesId) {
    return _seriesProgressCache[seriesId];
  }

  /// Clear progress cache for a specific series (useful after completion)
  void clearProgressCache(int seriesId) {
    _seriesProgressCache.remove(seriesId);
    notifyListeners();
  }

  /// Mark an episode as watched
  Future<EpisodeProgress> markEpisodeWatched(int episodeId, {bool isCompleted = true}) async {
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final result = await _service.markEpisodeWatched(episodeId, isCompleted: isCompleted, token: token);
      error = null;

      // Clear cache for this series to force fresh reload
      _seriesProgressCache.remove(result.seriesId);
      
      // Refresh progress for the series after marking episode
      if (result.seriesId > 0) {
        await loadSeriesProgress(result.seriesId);
      }
      
      return result;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }


  /// Load progress for a series
  Future<SeriesProgress> loadSeriesProgress(int seriesId) async {
    loading = true;
    notifyListeners();

    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final progress = await _service.getSeriesProgress(seriesId, token: token);
      _seriesProgressCache[seriesId] = progress;
      error = null;
      return progress;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Load progress for a series without setting global loading state (for batch loading)
  /// This is used when loading multiple series in parallel to avoid UI flickering
  Future<SeriesProgress?> loadSeriesProgressSilent(int seriesId) async {
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        return null;
      }

      final progress = await _service.getSeriesProgress(seriesId, token: token);
      _seriesProgressCache[seriesId] = progress;
      return progress;
    } catch (e) {
      // Silently fail for batch operations - don't set error state
      return null;
    }
  }

  /// Remove episode progress
  Future<void> removeProgress(int episodeId) async {
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      await _service.removeProgress(episodeId, token: token);
      _seriesProgressCache.clear();
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Get the next episode to watch for a series
  Future<int?> getNextEpisodeId(int seriesId) async {
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final nextEpisodeData = await _service.getNextEpisode(seriesId, token: token);
      if (nextEpisodeData != null && nextEpisodeData['episodeId'] != null) {
        return nextEpisodeData['episodeId'] as int;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get the last watched episode ID for a series
  Future<int?> getLastWatchedEpisodeId(int seriesId) async {
    try {
      final token = _authProvider?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final lastEpisodeData = await _service.getLastWatchedEpisode(seriesId, token: token);
      if (lastEpisodeData != null && lastEpisodeData['episodeId'] != null) {
        return lastEpisodeData['episodeId'] as int;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

