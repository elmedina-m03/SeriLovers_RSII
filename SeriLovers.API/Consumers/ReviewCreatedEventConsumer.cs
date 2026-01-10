using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Events;
using SeriLovers.API.Models;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace SeriLovers.API.Consumers
{
    /// <summary>
    /// Consumer for ReviewCreatedEvent - updates recommendation data based on user reviews
    /// </summary>
    public class ReviewCreatedEventConsumer : BaseEventConsumer
    {
        private readonly ApplicationDbContext _context;

        public ReviewCreatedEventConsumer(
            ApplicationDbContext context,
            ILogger<ReviewCreatedEventConsumer> logger)
            : base(logger)
        {
            _context = context;
        }

        /// <summary>
        /// Handles ReviewCreatedEvent
        /// </summary>
        public async Task HandleAsync(ReviewCreatedEvent @event, CancellationToken cancellationToken = default)
        {
            _logger.LogInformation(
                "[Consumer] Processing ReviewCreatedEvent - RatingId: {RatingId}, UserId: {UserId}, SeriesId: {SeriesId}, Score: {Score}",
                @event.RatingId, @event.UserId, @event.SeriesId, @event.Score);

            try
            {
                await ExecuteWithRetryAsync(async () =>
                {
                    await ProcessReviewCreatedAsync(@event, cancellationToken);
                },
                $"ReviewCreatedEvent processing for RatingId={@event.RatingId}, UserId={@event.UserId}",
                cancellationToken);

                _logger.LogInformation(
                    "[Consumer] Successfully processed ReviewCreatedEvent - RatingId: {RatingId}, UserId: {UserId}",
                    @event.RatingId, @event.UserId);
            }
            catch (Exception ex)
            {
                _logger.LogError(
                    ex,
                    "[Consumer] Failed to process ReviewCreatedEvent after retries - RatingId: {RatingId}, UserId: {UserId}",
                    @event.RatingId, @event.UserId);
                
                // Re-throw to allow EasyNetQ to handle dead-letter queue if configured
                throw;
            }
        }

        private async Task ProcessReviewCreatedAsync(ReviewCreatedEvent @event, CancellationToken cancellationToken)
        {
            // Update recommendation logs to mark as watched if user rated highly
            // High ratings (8+) indicate the user watched and enjoyed the series
            if (@event.Score >= 8)
            {
                await UpdateRecommendationLogsForReviewAsync(
                    @event.UserId, 
                    @event.SeriesId, 
                    true, 
                    cancellationToken);
            }

            _logger.LogInformation(
                "[Consumer] Review data logged for recommendations - UserId: {UserId}, SeriesId: {SeriesId}, Score: {Score}",
                @event.UserId, @event.SeriesId, @event.Score);
        }

        /// <summary>
        /// Updates recommendation logs based on review score
        /// </summary>
        private async Task UpdateRecommendationLogsForReviewAsync(
            int userId, 
            int seriesId, 
            bool watched, 
            CancellationToken cancellationToken)
        {
            try
            {
                var recommendationLogs = await _context.RecommendationLogs
                    .Where(rl => rl.UserId == userId 
                              && rl.SeriesId == seriesId 
                              && !rl.Watched)
                    .ToListAsync(cancellationToken);

                if (recommendationLogs.Any())
                {
                    foreach (var log in recommendationLogs)
                    {
                        log.Watched = watched;
                    }

                    await _context.SaveChangesAsync(cancellationToken);

                    _logger.LogInformation(
                        "Updated {Count} recommendation log(s) based on review - UserId: {UserId}, SeriesId: {SeriesId}, Watched: {Watched}",
                        recommendationLogs.Count, userId, seriesId, watched);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(
                    ex,
                    "Failed to update recommendation logs based on review - UserId: {UserId}, SeriesId: {SeriesId}",
                    userId, seriesId);
                // Don't fail the entire operation if recommendation log update fails
            }
        }
    }
}

