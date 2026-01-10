using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;
using SeriLovers.API.Events;
using SeriLovers.API.Models;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace SeriLovers.API.Consumers
{
    /// <summary>
    /// Consumer for EpisodeWatchedEvent - updates user progress and recommendation data
    /// </summary>
    public class EpisodeWatchedEventConsumer : BaseEventConsumer
    {
        private readonly ApplicationDbContext _context;
        private readonly ISeriesWatchingStateService _stateService;

        public EpisodeWatchedEventConsumer(
            ApplicationDbContext context,
            ISeriesWatchingStateService stateService,
            ILogger<EpisodeWatchedEventConsumer> logger)
            : base(logger)
        {
            _context = context;
            _stateService = stateService;
        }

        /// <summary>
        /// Handles EpisodeWatchedEvent
        /// </summary>
        public async Task HandleAsync(EpisodeWatchedEvent @event, CancellationToken cancellationToken = default)
        {
            _logger.LogInformation(
                "[Consumer] Processing EpisodeWatchedEvent - EpisodeId: {EpisodeId}, UserId: {UserId}, SeriesId: {SeriesId}, IsCompleted: {IsCompleted}",
                @event.EpisodeId, @event.UserId, @event.SeriesId, @event.IsCompleted);

            try
            {
                await ExecuteWithRetryAsync(async () =>
                {
                    await ProcessEpisodeWatchedAsync(@event, cancellationToken);
                }, 
                $"EpisodeWatchedEvent processing for EpisodeId={@event.EpisodeId}, UserId={@event.UserId}",
                cancellationToken);

                _logger.LogInformation(
                    "[Consumer] Successfully processed EpisodeWatchedEvent - EpisodeId: {EpisodeId}, UserId: {UserId}",
                    @event.EpisodeId, @event.UserId);
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "[Consumer] Failed to process EpisodeWatchedEvent after retries - EpisodeId: {EpisodeId}, UserId: {UserId}",
                    @event.EpisodeId, @event.UserId);
                
                // Re-throw to allow EasyNetQ to handle dead-letter queue if configured
                throw;
            }
        }

        private async Task ProcessEpisodeWatchedAsync(EpisodeWatchedEvent @event, CancellationToken cancellationToken)
        {
            // Only process completed episodes for progress tracking
            if (!@event.IsCompleted)
            {
                _logger.LogDebug(
                    "Skipping incomplete episode watch - EpisodeId: {EpisodeId}, UserId: {UserId}",
                    @event.EpisodeId, @event.UserId);
                return;
            }

            // Update recommendation logs if this series was recommended
            await UpdateRecommendationLogsAsync(@event.UserId, @event.SeriesId, cancellationToken);

            // Update user watching state (for future use with state machine)
            try
            {
                var currentState = await _stateService.GetStatusAsync(@event.UserId, @event.SeriesId);
                _logger.LogDebug(
                    "Current watching state for UserId={UserId}, SeriesId={SeriesId}: {State}",
                    @event.UserId, @event.SeriesId, currentState);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Failed to get watching state for UserId={UserId}, SeriesId={SeriesId}",
                    @event.UserId, @event.SeriesId);
                // Don't fail the entire operation if state check fails
            }

            // Log progress update
            _logger.LogInformation(
                "[Consumer] Updated progress tracking - UserId: {UserId}, SeriesId: {SeriesId}, EpisodeId: {EpisodeId}",
                @event.UserId, @event.SeriesId, @event.EpisodeId);
        }

        /// <summary>
        /// Updates recommendation logs when a user watches a recommended series
        /// </summary>
        private async Task UpdateRecommendationLogsAsync(int userId, int seriesId, CancellationToken cancellationToken)
        {
            try
            {
                // Find recommendation logs for this user and series
                var recommendationLogs = await _context.RecommendationLogs
                    .Where(rl => rl.UserId == userId 
                              && rl.SeriesId == seriesId 
                              && !rl.Watched)
                    .ToListAsync(cancellationToken);

                if (recommendationLogs.Any())
                {
                    foreach (var log in recommendationLogs)
                    {
                        log.Watched = true;
                    }

                    await _context.SaveChangesAsync(cancellationToken);

                    _logger.LogInformation(
                        "Updated {Count} recommendation log(s) - UserId: {UserId}, SeriesId: {SeriesId}",
                        recommendationLogs.Count, userId, seriesId);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Failed to update recommendation logs - UserId: {UserId}, SeriesId: {SeriesId}",
                    userId, seriesId);
                // Don't fail the entire operation if recommendation log update fails
            }
        }
    }
}

