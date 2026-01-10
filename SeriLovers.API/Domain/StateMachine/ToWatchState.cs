using AutoMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;

namespace SeriLovers.API.Domain.StateMachine
{
    /// <summary>
    /// Initial state - user hasn't watched any episodes yet
    /// </summary>
    public class ToWatchState : BaseSeriesWatchingState
    {
        public override SeriesWatchingStatus StateName => SeriesWatchingStatus.ToWatch;

        public ToWatchState(
            IServiceProvider serviceProvider,
            ApplicationDbContext context,
            IMapper mapper,
            ILogger<BaseSeriesWatchingState> logger)
            : base(serviceProvider, context, mapper, logger)
        {
        }

        /// <summary>
        /// Updates state based on watched episode count
        /// ToWatch can transition to InProgress or Finished
        /// </summary>
        public override async Task<SeriesWatchingStatus> UpdateStateAsync(int userId, int seriesId, int totalEpisodes, int watchedEpisodes)
        {
            _logger.LogDebug("ToWatchState.UpdateStateAsync: UserId={UserId}, SeriesId={SeriesId}, Watched={Watched}/{Total}",
                userId, seriesId, watchedEpisodes, totalEpisodes);

            if (watchedEpisodes <= 0)
            {
                // Still ToWatch - persist current state
                await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.ToWatch, watchedEpisodes, totalEpisodes);
                return SeriesWatchingStatus.ToWatch;
            }

            // Determine target state based on watched episodes
            var targetState = CalculateStateFromProgress(totalEpisodes, watchedEpisodes);

            // ToWatch can transition to InProgress or Finished (if all watched at once)
            if (targetState == SeriesWatchingStatus.InProgress || targetState == SeriesWatchingStatus.Finished)
            {
                // Transition to new state - persist directly
                await PersistStateAsync(userId, seriesId, targetState, watchedEpisodes, totalEpisodes);
                return targetState;
            }

            // Default: persist ToWatch
            await PersistStateAsync(userId, seriesId, SeriesWatchingStatus.ToWatch, watchedEpisodes, totalEpisodes);
            return SeriesWatchingStatus.ToWatch;
        }
    }
}

