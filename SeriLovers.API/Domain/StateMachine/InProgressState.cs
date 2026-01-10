using AutoMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;

namespace SeriLovers.API.Domain.StateMachine
{
    /// <summary>
    /// InProgress state - user has watched some episodes but not all
    /// </summary>
    public class InProgressState : BaseSeriesWatchingState
    {
        public override SeriesWatchingStatus StateName => SeriesWatchingStatus.InProgress;

        public InProgressState(
            IServiceProvider serviceProvider,
            ApplicationDbContext context,
            IMapper mapper,
            ILogger<BaseSeriesWatchingState> logger)
            : base(serviceProvider, context, mapper, logger)
        {
        }

        /// <summary>
        /// Updates state based on watched episode count
        /// InProgress can transition to Finished (all watched) or back to ToWatch (all unwatched)
        /// </summary>
        public override async Task<SeriesWatchingStatus> UpdateStateAsync(int userId, int seriesId, int totalEpisodes, int watchedEpisodes)
        {
            _logger.LogDebug("InProgressState.UpdateStateAsync: UserId={UserId}, SeriesId={SeriesId}, Watched={Watched}/{Total}",
                userId, seriesId, watchedEpisodes, totalEpisodes);

            // Determine target state based on watched episodes
            var targetState = CalculateStateFromProgress(totalEpisodes, watchedEpisodes);

            if (targetState == SeriesWatchingStatus.Finished)
            {
                // Transition to Finished - all episodes watched
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.Finished, watchedEpisodes, totalEpisodes);
                return SeriesWatchingStatus.Finished;
            }
            else if (targetState == SeriesWatchingStatus.ToWatch)
            {
                // User unwatched all episodes - go back to ToWatch
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.ToWatch, watchedEpisodes, totalEpisodes);
                return SeriesWatchingStatus.ToWatch;
            }
            else
            {
                // Still InProgress - persist current state
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.InProgress, watchedEpisodes, totalEpisodes);
                return SeriesWatchingStatus.InProgress;
            }
        }
    }
}

