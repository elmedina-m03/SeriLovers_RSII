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
        /// Calculates the number of completed series for a user
        /// A series is considered completed if the user has watched at least 80% of its episodes
        /// </summary>
        public async Task<int> GetCompletedSeriesCountAsync(int userId)
        {
            // Get all series with their episode counts
            var seriesWithEpisodes = await _context.Series
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
                .GroupBy(ep => ep.SeriesId)
                .Select(g => new
                {
                    SeriesId = g.Key,
                    WatchedCount = g.Count()
                })
                .ToListAsync();

            // Count series where user has watched at least 80% of episodes
            int completedSeriesCount = 0;
            foreach (var series in seriesWithEpisodes)
            {
                var watchedData = watchedEpisodesBySeries.FirstOrDefault(w => w.SeriesId == series.SeriesId);
                var watchedCount = watchedData?.WatchedCount ?? 0;
                var completionPercentage = (double)watchedCount / series.TotalEpisodes;

                // A series is considered completed if user has watched 100% of episodes
                // Changed from 80% to 100% to match frontend logic
                if (completionPercentage >= 1.0) // 100% threshold (all episodes watched)
                {
                    completedSeriesCount++;
                }
            }

            return completedSeriesCount;
        }

        /// <summary>
        /// Updates challenge progress for a user based on their actual watched series count
        /// </summary>
        public async Task UpdateChallengeProgressAsync(int userId)
        {
            // Get completed series count for this user
            var completedSeriesCount = await GetCompletedSeriesCountAsync(userId);

            // Get all "Watch X Series" type challenges
            var watchSeriesChallenges = await _context.Challenges
                .Where(c => c.Name.Contains("Series") || (c.Description != null && c.Description.Contains("series")))
                .ToListAsync();

            foreach (var challenge in watchSeriesChallenges)
            {
                // Get or create challenge progress for this user
                var progress = await _context.ChallengeProgresses
                    .FirstOrDefaultAsync(cp => cp.ChallengeId == challenge.Id && cp.UserId == userId);

                if (progress == null)
                {
                    // Only create progress if user has started watching (has at least 1 completed series)
                    if (completedSeriesCount > 0)
                    {
                        progress = new ChallengeProgress
                        {
                            ChallengeId = challenge.Id,
                            UserId = userId,
                            ProgressCount = completedSeriesCount,
                            Status = completedSeriesCount >= challenge.TargetCount
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
                    // Update existing progress
                    progress.ProgressCount = completedSeriesCount;

                    // Update status if completed
                    if (completedSeriesCount >= challenge.TargetCount && progress.Status != ChallengeProgressStatus.Completed)
                    {
                        progress.Status = ChallengeProgressStatus.Completed;
                        progress.CompletedAt = DateTime.UtcNow;
                    }
                    else if (completedSeriesCount < challenge.TargetCount && progress.Status == ChallengeProgressStatus.Completed)
                    {
                        // If somehow progress went down, revert to InProgress
                        progress.Status = ChallengeProgressStatus.InProgress;
                        progress.CompletedAt = null;
                    }
                }
            }

            // Update participants count for all challenges
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

