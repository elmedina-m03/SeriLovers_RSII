using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Events;
using SeriLovers.API.Interfaces;

namespace SeriLovers.API.HostedServices
{
    public class MessageBusSubscriberHostedService : IHostedService
    {
        private readonly IMessageBusService _messageBusService;
        private readonly ILogger<MessageBusSubscriberHostedService> _logger;

        public MessageBusSubscriberHostedService(IMessageBusService messageBusService, ILogger<MessageBusSubscriberHostedService> logger)
        {
            _messageBusService = messageBusService;
            _logger = logger;
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Starting message bus subscriptions...");

            // Check if RabbitMQ is available before attempting subscriptions
            if (!_messageBusService.IsAvailable)
            {
                _logger.LogInformation("RabbitMQ is not available. Skipping message bus subscriptions.");
                return Task.CompletedTask;
            }

            // Start subscriptions in the background to avoid blocking application startup
            // Use Task.Run to ensure subscriptions don't block the startup process
            _ = Task.Run(async () =>
            {
                // Add a delay to ensure RabbitMQ connection is fully established
                // Increased delay to give RabbitMQ more time to initialize
                await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);

                // Wrap each subscription individually so one failure doesn't prevent others
                // Add small delays between subscriptions to avoid overwhelming RabbitMQ
                
                // Review Created Event
                try
                {
                    await _messageBusService.SubscribeAsync<ReviewCreatedEvent>("ReviewCreatedHandler", async message =>
                    {
                        _logger.LogInformation(
                            "[RabbitMQ] ReviewCreatedEvent received - RatingId: {RatingId}, User: {UserName} ({UserId}), Series: {SeriesTitle} ({SeriesId}), Score: {Score}, Comment: {Comment}",
                            message.RatingId, message.UserName, message.UserId, message.SeriesTitle, message.SeriesId, message.Score, 
                            string.IsNullOrEmpty(message.Comment) ? "No comment" : $"\"{message.Comment}\"");
                        await Task.CompletedTask;
                    });
                    _logger.LogInformation("Successfully subscribed to ReviewCreatedEvent.");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to subscribe to ReviewCreatedEvent. The application will continue without this subscription.");
                }

                // Small delay between subscriptions to avoid overwhelming RabbitMQ
                await Task.Delay(TimeSpan.FromSeconds(1), cancellationToken);

                // Episode Watched Event
                try
                {
                    await _messageBusService.SubscribeAsync<EpisodeWatchedEvent>("EpisodeWatchedHandler", async message =>
                    {
                        _logger.LogInformation(
                            "[RabbitMQ] EpisodeWatchedEvent received - EpisodeId: {EpisodeId}, User: {UserName} ({UserId}), Series: {SeriesTitle} ({SeriesId}), Season {SeasonNumber} Episode {EpisodeNumber}, Completed: {IsCompleted}",
                            message.EpisodeId, message.UserName, message.UserId, message.SeriesTitle, message.SeriesId, 
                            message.SeasonNumber, message.EpisodeNumber, message.IsCompleted);
                        await Task.CompletedTask;
                    });
                    _logger.LogInformation("Successfully subscribed to EpisodeWatchedEvent.");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to subscribe to EpisodeWatchedEvent. The application will continue without this subscription.");
                }

                // Small delay between subscriptions to avoid overwhelming RabbitMQ
                await Task.Delay(TimeSpan.FromSeconds(1), cancellationToken);

                // User Created Event
                try
                {
                    await _messageBusService.SubscribeAsync<UserCreatedEvent>("UserCreatedHandler", async message =>
                    {
                        _logger.LogInformation(
                            "[RabbitMQ] UserCreatedEvent received - UserId: {UserId}, UserName: {UserName}, Email: {Email}",
                            message.UserId, message.UserName, message.Email);
                        await Task.CompletedTask;
                    });
                    _logger.LogInformation("Successfully subscribed to UserCreatedEvent.");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to subscribe to UserCreatedEvent. The application will continue without this subscription.");
                }

                // Small delay between subscriptions to avoid overwhelming RabbitMQ
                await Task.Delay(TimeSpan.FromSeconds(1), cancellationToken);

                // User Updated Event
                try
                {
                    await _messageBusService.SubscribeAsync<UserUpdatedEvent>("UserUpdatedHandler", async message =>
                    {
                        _logger.LogInformation(
                            "[RabbitMQ] UserUpdatedEvent received - UserId: {UserId}, UserName: {UserName}, Email: {Email}, Country: {Country}, AvatarUrl: {AvatarUrl}",
                            message.UserId, message.UserName, message.Email, message.Country ?? "N/A", message.AvatarUrl ?? "N/A");
                        await Task.CompletedTask;
                    });
                    _logger.LogInformation("Successfully subscribed to UserUpdatedEvent.");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to subscribe to UserUpdatedEvent. The application will continue without this subscription.");
                }

                _logger.LogInformation("Message bus subscription initialization completed.");
            }, cancellationToken);

            // Return immediately to not block startup
            return Task.CompletedTask;
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }
}
