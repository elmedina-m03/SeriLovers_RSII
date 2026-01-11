using EasyNetQ;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Events;
using SeriLovers.Worker.Data;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace SeriLovers.Worker
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly IConfiguration _configuration;
        private readonly IServiceProvider _serviceProvider;
        private IBus? _bus;

        public Worker(
            ILogger<Worker> logger,
            IConfiguration configuration,
            IServiceProvider serviceProvider)
        {
            _logger = logger;
            _configuration = configuration;
            _serviceProvider = serviceProvider;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Worker service starting...");

            try
            {
                var connectionString = _configuration["RabbitMq:Connection"]
                    ?? Environment.GetEnvironmentVariable("RABBITMQ_CONNECTION");

                if (string.IsNullOrWhiteSpace(connectionString))
                {
                    _logger.LogError("RabbitMQ connection string is not configured. Worker cannot start.");
                    return;
                }

                _logger.LogInformation("Connecting to RabbitMQ...");
                _bus = RabbitHutch.CreateBus(connectionString);
                _logger.LogInformation("Successfully connected to RabbitMQ.");

                await Task.Delay(TimeSpan.FromSeconds(2), stoppingToken);

                await SubscribeToEventsAsync(stoppingToken);

                _logger.LogInformation("Worker service started. Waiting for messages...");

                while (!stoppingToken.IsCancellationRequested)
                {
                    await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in Worker service.");
                throw;
            }
        }

        private async Task SubscribeToEventsAsync(CancellationToken cancellationToken)
        {
            if (_bus == null)
            {
                _logger.LogError("RabbitMQ bus is not initialized.");
                return;
            }

            await _bus.PubSub.SubscribeAsync<EpisodeWatchedEvent>(
                "Worker_EpisodeWatchedHandler",
                async message =>
                {
                    _logger.LogInformation(
                        "[Worker] Received EpisodeWatchedEvent - EpisodeId: {EpisodeId}, UserId: {UserId}, SeriesId: {SeriesId}",
                        message.EpisodeId, message.UserId, message.SeriesId);

                    try
                    {
                        using var scope = _serviceProvider.CreateScope();
                        var context = scope.ServiceProvider.GetRequiredService<WorkerDbContext>();

                        if (message.IsCompleted)
                        {
                            await UpdateRecommendationLogsAsync(context, message.UserId, message.SeriesId, cancellationToken);
                        }

                        _logger.LogInformation(
                            "[Worker] Successfully processed EpisodeWatchedEvent - EpisodeId: {EpisodeId}",
                            message.EpisodeId);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex,
                            "[Worker] Failed to process EpisodeWatchedEvent - EpisodeId: {EpisodeId}",
                            message.EpisodeId);
                        throw;
                    }
                },
                cancellationToken);

            _logger.LogInformation("[Worker] Subscribed to EpisodeWatchedEvent.");

            await _bus.PubSub.SubscribeAsync<ReviewCreatedEvent>(
                "Worker_ReviewCreatedHandler",
                async message =>
                {
                    _logger.LogInformation(
                        "[Worker] Received ReviewCreatedEvent - RatingId: {RatingId}, UserId: {UserId}, SeriesId: {SeriesId}, Score: {Score}",
                        message.RatingId, message.UserId, message.SeriesId, message.Score);

                    try
                    {
                        using var scope = _serviceProvider.CreateScope();
                        var context = scope.ServiceProvider.GetRequiredService<WorkerDbContext>();

                        if (message.Score >= 8)
                        {
                            await UpdateRecommendationLogsAsync(context, message.UserId, message.SeriesId, cancellationToken);
                        }

                        _logger.LogInformation(
                            "[Worker] Successfully processed ReviewCreatedEvent - RatingId: {RatingId}",
                            message.RatingId);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex,
                            "[Worker] Failed to process ReviewCreatedEvent - RatingId: {RatingId}",
                            message.RatingId);
                        throw;
                    }
                },
                cancellationToken);

            _logger.LogInformation("[Worker] Subscribed to ReviewCreatedEvent.");
        }

        private static async Task UpdateRecommendationLogsAsync(
            WorkerDbContext context,
            int userId,
            int seriesId,
            CancellationToken cancellationToken)
        {
            var recommendationLogs = await context.RecommendationLogs
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

                await context.SaveChangesAsync(cancellationToken);
            }
        }

        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Worker service stopping...");

            if (_bus != null)
            {
                _bus.Dispose();
            }

            await base.StopAsync(cancellationToken);
            _logger.LogInformation("Worker service stopped.");
        }
    }
}
