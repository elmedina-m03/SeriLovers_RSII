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
        /// Finished can transition back to InProgress or ToWatch if user unwatches episodes
        /// </summary>
        public override async Task<SeriesWatchingStatus> UpdateStateAsync(int userId, int seriesId, int totalEpisodes, int watchedEpisodes)
        {
            _logger.LogDebug("FinishedState.UpdateStateAsync: UserId={UserId}, SeriesId={SeriesId}, Watched={Watched}/{Total}",
                userId, seriesId, watchedEpisodes, totalEpisodes);

            // Determine target state based on watched episodes
            var targetState = CalculateStateFromProgress(totalEpisodes, watchedEpisodes);

            if (targetState == SeriesWatchingStatus.InProgress)
            {
                // User unwatched some episodes - go back to InProgress
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.InProgress, watchedEpisodes, totalEpisodes);
                return SeriesWatchingStatus.InProgress;
            }
            else if (targetState == SeriesWatchingStatus.ToWatch)
            {
                // User unwatched all episodes - go back to ToWatch
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.ToWatch, watchedEpisodes, totalEpisodes);
                return SeriesWatchingStatus.ToWatch;
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

