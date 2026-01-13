using AutoMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;

namespace SeriLovers.API.Domain.StateMachine
{
    /// <summary>
    /// Finished state - user has watched all episodes
    /// Reviews can be created in this state
    /// </summary>
    public class FinishedState : BaseSeriesWatchingState
    {
        public override SeriesWatchingStatus StateName => SeriesWatchingStatus.Finished;

        public FinishedState(
            IServiceProvider serviceProvider,
            ApplicationDbContext context,
            IMapper mapper,
            ILogger<BaseSeriesWatchingState> logger)
            : base(serviceProvider, context, mapper, logger)
        {
        }

        /// <summary>
        /// Updates state based on watched episode count
        /// CRITICAL: Once a series is Finished, it cannot go back to InProgress or ToWatch
        /// unless the user explicitly deletes episode progress (which should be rare).
        /// This prevents finished series from reverting to InProgress after app restart.
        /// </summary>
        public override async Task<SeriesWatchingStatus> UpdateStateAsync(int userId, int seriesId, int totalEpisodes, int watchedEpisodes)
        {
            _logger.LogDebug("FinishedState.UpdateStateAsync: UserId={UserId}, SeriesId={SeriesId}, Watched={Watched}/{Total}",
                userId, seriesId, watchedEpisodes, totalEpisodes);

            // CRITICAL: Check if user has a review for this series
            // If they do, the series must remain Finished (cannot revert to InProgress)
            var hasReview = await _context.Ratings
                .AnyAsync(r => r.UserId == userId && r.SeriesId == seriesId);

            // Determine target state based on watched episodes
            var targetState = BaseSeriesWatchingState.CalculateState(totalEpisodes, watchedEpisodes);

            // If series has a review, it MUST remain Finished (cannot revert)
            if (hasReview)
            {
                _logger.LogInformation("Series {SeriesId} for User {UserId} has a review. Keeping status as Finished even if watchedEpisodes ({Watched}/{Total}) suggests otherwise.",
                    seriesId, userId, watchedEpisodes, totalEpisodes);
                
                // Ensure all episodes are marked as watched to maintain consistency
                if (watchedEpisodes < totalEpisodes)
                {
                    _logger.LogWarning("Series {SeriesId} for User {UserId} has review but watchedEpisodes ({Watched}/{Total}) is less than total. This may indicate data inconsistency.",
                        seriesId, userId, watchedEpisodes, totalEpisodes);
                }
                
                // Always persist as Finished if review exists
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.Finished, totalEpisodes, totalEpisodes);
                return SeriesWatchingStatus.Finished;
            }

            // No review exists - allow transition only if ALL episodes are unwatched
            // This prevents accidental reversion due to data inconsistencies
            if (targetState == SeriesWatchingStatus.ToWatch && watchedEpisodes == 0)
            {
                // User explicitly unwatched ALL episodes - go back to ToWatch
                _logger.LogInformation("Series {SeriesId} for User {UserId} - all episodes unwatched. Transitioning from Finished to ToWatch.",
                    seriesId, userId);
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.ToWatch, 0, totalEpisodes);
                return SeriesWatchingStatus.ToWatch;
            }
            else if (targetState == SeriesWatchingStatus.InProgress)
            {
                // User unwatched some episodes but not all
                // CRITICAL: If series was previously Finished, do NOT revert to InProgress
                // This prevents finished series from reverting after app restart due to data inconsistencies
                _logger.LogWarning("Series {SeriesId} for User {UserId} was Finished but watchedEpisodes ({Watched}/{Total}) suggests InProgress. " +
                    "Keeping as Finished to prevent accidental reversion. If user truly unwatched episodes, they should explicitly remove progress.",
                    seriesId, userId, watchedEpisodes, totalEpisodes);
                
                // Keep as Finished to prevent accidental reversion
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.Finished, totalEpisodes, totalEpisodes);
                return SeriesWatchingStatus.Finished;
            }
            else
            {
                // Still Finished - persist current state
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.Finished, watchedEpisodes, totalEpisodes);
                return SeriesWatchingStatus.Finished;
            }
        }

        /// <summary>
        /// Finished state allows review creation
        /// </summary>
        public override void ValidateReviewCreation()
        {
            // Reviews are allowed in Finished state - no exception thrown
            _logger.LogDebug("Review creation validated for Finished state");
        }
    }
}

