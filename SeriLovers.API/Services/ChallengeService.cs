using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Services
{
    /// <summary>
    /// Service for calculating and updating challenge progress from real user activity
    /// </summary>
    public class ChallengeService
    {
        private readonly ApplicationDbContext _context;

        public ChallengeService(ApplicationDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Extracts genre name from challenge name (e.g., "Complete 5 Drama Series" → "Drama")
        /// Returns null if no genre is found
        /// </summary>
        private string? ExtractGenreFromChallengeName(string challengeName, List<string> allGenres)
        {
            // Check if challenge name contains any genre name (case-insensitive)
            foreach (var genreName in allGenres)
            {
                if (challengeName.Contains(genreName, StringComparison.OrdinalIgnoreCase))
                {
                    return genreName;
                }
            }

            return null;
        }

        /// <summary>
        /// Calculates the number of completed series for a user
        /// A series is considered completed if the user has watched 100% of its episodes
        /// Since ratings can only be created after completing 100% of episodes, we use ratings as the primary source
        /// and verify with EpisodeProgress data
        /// If genreName is provided, only counts series that have that genre
        /// </summary>
        public async Task<int> GetCompletedSeriesCountAsync(int userId, string? genreName = null)
        {
            // Primary method: Count series that user has rated
            // Ratings can only be created after completing 100% of episodes (enforced by HasUserCompletedSeries)
            // Each user can only rate each series once (unique constraint)
            var ratedSeriesQuery = _context.Ratings
                .Where(r => r.UserId == userId);

            // Filter by genre if provided
            if (!string.IsNullOrWhiteSpace(genreName))
            {
                var genre = await _context.Genres
                    .FirstOrDefaultAsync(g => g.Name == genreName);

                if (genre != null)
                {
                    ratedSeriesQuery = ratedSeriesQuery
                        .Where(r => _context.SeriesGenres
                            .Any(sg => sg.SeriesId == r.SeriesId && sg.GenreId == genre.Id));
                }
            }

            var ratedSeriesCount = await ratedSeriesQuery
                .Select(r => r.SeriesId)
                .Distinct()
                .CountAsync();

            var allSeriesQuery = _context.Series.AsQueryable();

            // Filter by genre if provided
            if (!string.IsNullOrWhiteSpace(genreName))
            {
                var genre = await _context.Genres
                    .FirstOrDefaultAsync(g => g.Name == genreName);

                if (genre != null)
                {
                    allSeriesQuery = allSeriesQuery
                        .Where(s => _context.SeriesGenres
                            .Any(sg => sg.SeriesId == s.Id && sg.GenreId == genre.Id));
                }
            }

            var allSeries = await allSeriesQuery
                .Select(s => new
                {
                    SeriesId = s.Id,
                    TotalEpisodes = s.Seasons
                        .SelectMany(season => season.Episodes)
                        .Count()
                })
                .ToListAsync();

            // Get watched episodes per series for this user
            var watchedEpisodesBySeries = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId && ep.IsCompleted)
                .Select(ep => new
                {
                    SeriesId = ep.Episode.Season.SeriesId,
                    EpisodeId = ep.EpisodeId
                })
                .Distinct()
                .GroupBy(ep => ep.SeriesId)
                .Select(g => new
                {
                    SeriesId = g.Key,
                    WatchedCount = g.Count()
                })
                .ToListAsync();

            int completedByProgressCount = 0;
            foreach (var series in allSeries)
            {
                var watchedData = watchedEpisodesBySeries.FirstOrDefault(w => w.SeriesId == series.SeriesId);
                var watchedCount = watchedData?.WatchedCount ?? 0;
                
                if (series.TotalEpisodes == 0)
                {
                    // Series with no episodes: skip (can't verify completion via progress)
                    continue;
                }
                
                // Safety check: watchedCount cannot exceed total episodes
                if (watchedCount > series.TotalEpisodes)
                {
                    continue;
                }
                
                var completionPercentage = (double)watchedCount / series.TotalEpisodes;
                
                // A series is considered completed if user has watched 100% of episodes
                if (completionPercentage >= 1.0)
                {
                    completedByProgressCount++;
                }
            }

            // Return the maximum of the two counts
            // Ratings are the source of truth (since they require 100% completion),
            // but if EpisodeProgress shows more, we use that (handles edge cases)
            return Math.Max(ratedSeriesCount, completedByProgressCount);
        }

        /// <summary>
        /// Calculates the number of series that are BOTH watched (100% of episodes) AND rated by a user
        /// Used for "watch and rate" type challenges
        /// If genreName is provided, only counts series that have that genre
        /// </summary>
        public async Task<int> GetWatchedAndRatedSeriesCountAsync(int userId, string? genreName = null)
        {
            // Get all series with their episode counts
            var seriesWithEpisodesQuery = _context.Series.AsQueryable();

            // Filter by genre if provided
            if (!string.IsNullOrWhiteSpace(genreName))
            {
                var genre = await _context.Genres
                    .FirstOrDefaultAsync(g => g.Name == genreName);

                if (genre != null)
                {
                    seriesWithEpisodesQuery = seriesWithEpisodesQuery
                        .Where(s => _context.SeriesGenres
                            .Any(sg => sg.SeriesId == s.Id && sg.GenreId == genre.Id));
                }
            }

            var seriesWithEpisodes = await seriesWithEpisodesQuery
                .Select(s => new
                {
                    SeriesId = s.Id,
                    TotalEpisodes = s.Seasons
                        .SelectMany(season => season.Episodes)
                        .Count()
                })
                .Where(s => s.TotalEpisodes > 0) // Only series with episodes
                .ToListAsync();

            // Get watched episodes per series for this user
            var watchedEpisodesBySeries = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId && ep.IsCompleted)
                .Select(ep => new
                {
                    SeriesId = ep.Episode.Season.SeriesId,
                    EpisodeId = ep.EpisodeId
                })
                .Distinct()
                .GroupBy(ep => ep.SeriesId)
                .Select(g => new
                {
                    SeriesId = g.Key,
                    WatchedCount = g.Count()
                })
                .ToListAsync();

            // Get all series rated by this user
            var ratedSeriesIds = await _context.Ratings
                .Where(r => r.UserId == userId)
                .Select(r => r.SeriesId)
                .Distinct()
                .ToListAsync();

            // Count series that are BOTH watched (100%) AND rated
            int watchedAndRatedCount = 0;
            foreach (var series in seriesWithEpisodes)
            {
                var watchedData = watchedEpisodesBySeries.FirstOrDefault(w => w.SeriesId == series.SeriesId);
                var watchedCount = watchedData?.WatchedCount ?? 0;
                
                // Safety check: watchedCount cannot exceed total episodes
                if (watchedCount > series.TotalEpisodes)
                {
                    continue;
                }
                
                var completionPercentage = (double)watchedCount / series.TotalEpisodes;
                var isRated = ratedSeriesIds.Contains(series.SeriesId);

                // Series must be BOTH watched (100%) AND rated
                if (completionPercentage >= 1.0 && isRated)
                {
                    watchedAndRatedCount++;
                }
            }

            // Safety check: count cannot exceed total series count
            var totalSeriesCount = seriesWithEpisodes.Count;
            return Math.Min(watchedAndRatedCount, totalSeriesCount);
        }

        /// <summary>
        /// Updates challenge progress for a user based on their actual watched series count
        /// Handles both "watch only" and "watch and rate" type challenges
        /// Supports genre-based filtering (e.g., "Complete 5 Drama Series")
        /// </summary>
        public async Task UpdateChallengeProgressAsync(int userId)
        {
            // Load all genres once for genre extraction
            var allGenres = await _context.Genres
                .Select(g => g.Name)
                .ToListAsync();

            // Get all challenges that involve watching series
            var watchSeriesChallenges = await _context.Challenges
                .Where(c => c.Name.Contains("Series") || 
                           (c.Description != null && c.Description.Contains("series")))
                .ToListAsync();

            foreach (var challenge in watchSeriesChallenges)
            {
                // Extract genre from challenge name if present (e.g., "Complete 5 Drama Series" → "Drama")
                var genreName = ExtractGenreFromChallengeName(challenge.Name ?? "", allGenres);

                // Determine if this is a "watch and rate" challenge
                // Check if challenge name or description contains "rate" or "rated"
                var isWatchAndRateChallenge = (challenge.Name != null && 
                    (challenge.Name.Contains("rate", StringComparison.OrdinalIgnoreCase) ||
                     challenge.Name.Contains("rated", StringComparison.OrdinalIgnoreCase))) ||
                    (challenge.Description != null && 
                    (challenge.Description.Contains("rate", StringComparison.OrdinalIgnoreCase) ||
                     challenge.Description.Contains("rated", StringComparison.OrdinalIgnoreCase)));

                // Get count based on challenge type and genre filter
                int progressCount;
                if (isWatchAndRateChallenge)
                {
                    progressCount = await GetWatchedAndRatedSeriesCountAsync(userId, genreName);
                }
                else
                {
                    progressCount = await GetCompletedSeriesCountAsync(userId, genreName);
                }

                // Get or create challenge progress for this user
                var progress = await _context.ChallengeProgresses
                    .FirstOrDefaultAsync(cp => cp.ChallengeId == challenge.Id && cp.UserId == userId);

                if (progress == null)
                {
                    // Only create progress if user has started (has at least 1 completed/watched-and-rated series)
                    if (progressCount > 0)
                    {
                        progress = new ChallengeProgress
                        {
                            ChallengeId = challenge.Id,
                            UserId = userId,
                            ProgressCount = progressCount,
                            Status = progressCount >= challenge.TargetCount
                                ? ChallengeProgressStatus.Completed
                                : ChallengeProgressStatus.InProgress
                        };

                        if (progress.Status == ChallengeProgressStatus.Completed)
                        {
                            progress.CompletedAt = DateTime.UtcNow;
                        }

                        _context.ChallengeProgresses.Add(progress);
                    }
                }
                else
                {
                    // Update existing progress with validated count
                    // Get total series count to ensure ProgressCount never exceeds it
                    var totalSeriesCount = await _context.Series.CountAsync();
                    var validatedCount = Math.Min(progressCount, totalSeriesCount);
                    
                    progress.ProgressCount = validatedCount;

                    // Update status if completed
                    if (validatedCount >= challenge.TargetCount && progress.Status != ChallengeProgressStatus.Completed)
                    {
                        progress.Status = ChallengeProgressStatus.Completed;
                        progress.CompletedAt = DateTime.UtcNow;
                    }
                    else if (validatedCount < challenge.TargetCount && progress.Status == ChallengeProgressStatus.Completed)
                    {
                        progress.Status = ChallengeProgressStatus.InProgress;
                        progress.CompletedAt = null;
                    }
                }
            }

            // Update participants count for all challenges using pure EF Core queries
            var allChallenges = await _context.Challenges.ToListAsync();
            
            foreach (var challenge in allChallenges)
            {
                challenge.ParticipantsCount = await _context.ChallengeProgresses
                    .CountAsync(cp => cp.ChallengeId == challenge.Id);
            }

            await _context.SaveChangesAsync();
        }
    }
}

