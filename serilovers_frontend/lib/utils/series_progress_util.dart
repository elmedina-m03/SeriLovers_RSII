import '../models/series.dart';
import '../models/episode_progress.dart';

/// Utility class for calculating series-level progress
class SeriesProgressUtil {
  /// Calculate total episodes across all seasons in a series
  /// Sums episodes from ALL seasons (e.g., 3 seasons × 5 episodes = 15 total)
  static int calculateTotalEpisodes(Series series) {
    if (series.seasons.isEmpty) {
      return 0;
    }
    // Sum episodes across ALL seasons
    return series.seasons.fold(0, (sum, season) {
      final episodeCount = season.episodes?.length ?? 0;
      return sum + episodeCount;
    });
  }

  /// Calculate watched episodes count from progress data
  static int calculateWatchedEpisodes(SeriesProgress? progress) {
    return progress?.watchedEpisodes ?? 0;
  }

  /// Calculate progress percentage
  static double calculateProgressPercentage(int watchedEpisodes, int totalEpisodes) {
    if (totalEpisodes == 0) {
      return 0.0;
    }
    return (watchedEpisodes / totalEpisodes) * 100.0;
  }

  /// Determine series status based on watched episodes
  /// Returns: 'To Do', 'In Progress', or 'Finished'
  static SeriesStatus determineStatus(int watchedEpisodes, int totalEpisodes) {
    if (watchedEpisodes == 0) {
      return SeriesStatus.toDo;
    } else if (watchedEpisodes >= totalEpisodes && totalEpisodes > 0) {
      return SeriesStatus.finished;
    } else {
      return SeriesStatus.inProgress;
    }
  }

  /// Get status from SeriesProgress
  static SeriesStatus getStatusFromProgress(SeriesProgress? progress, int totalEpisodes) {
    final watchedEpisodes = calculateWatchedEpisodes(progress);
    return determineStatus(watchedEpisodes, totalEpisodes);
  }

  /// Check if series should be shown in status screen
  /// Only show series that have been started (watchedEpisodes > 0)
  static bool shouldShowInStatus(int watchedEpisodes) {
    return watchedEpisodes > 0;
  }

  /// Format progress text (e.g., "5/15 episodes")
  static String formatProgressText(int watchedEpisodes, int totalEpisodes) {
    if (totalEpisodes == 0) {
      return 'No episodes';
    }
    if (watchedEpisodes == 0) {
      return 'Not started';
    }
    return '$watchedEpisodes/$totalEpisodes episodes';
  }
}

/// Series status enum
enum SeriesStatus {
  toDo,
  inProgress,
  finished,
}

