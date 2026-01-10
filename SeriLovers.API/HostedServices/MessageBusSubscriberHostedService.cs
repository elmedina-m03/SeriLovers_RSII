using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Consumers;
using SeriLovers.API.Events;
using SeriLovers.API.Interfaces;

namespace SeriLovers.API.HostedServices
{
    public class MessageBusSubscriberHostedService : IHostedService
    {
        private readonly IMessageBusService _messageBusService;
        private readonly ILogger<MessageBusSubscriberHostedService> _logger;
        private readonly IServiceProvider _serviceProvider;
        private readonly IHostEnvironment _hostEnvironment;

        public MessageBusSubscriberHostedService(
            IMessageBusService messageBusService,
            ILogger<MessageBusSubscriberHostedService> logger,
            IServiceProvider serviceProvider,
            IHostEnvironment hostEnvironment)
        {
            _messageBusService = messageBusService;
            _logger = logger;
            _serviceProvider = serviceProvider;
            _hostEnvironment = hostEnvironment;
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            if (_hostEnvironment.IsDevelopment())
            {
                _logger.LogInformation("Development environment detected. Skipping RabbitMQ subscriptions.");
                return Task.CompletedTask;
            }

            _logger.LogInformation("Starting message bus subscriptions...");

            if (!_messageBusService.IsAvailable)
            {
                _logger.LogWarning("RabbitMQ is not available. Skipping message bus subscriptions.");
                return Task.CompletedTask;
            }

            // Start subscriptions in the background to avoid blocking application startup
            // Use fire-and-forget pattern with proper error handling for each subscription
            _ = Task.Run(async () =>
            {
                try
                {
                    // Add a delay to ensure RabbitMQ connection is fully established
                    await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);

                    // Wrap each subscription individually so one failure doesn't prevent others
                    // Each subscription is handled independently with try/catch
                    
                    // Review Created Event
                    try
                    {
                        await _messageBusService.SubscribeAsync<ReviewCreatedEvent>("ReviewCreatedHandler", async message =>
                        {
                            _logger.LogInformation(
                                "[RabbitMQ] ReviewCreatedEvent received - RatingId: {RatingId}, User: {UserName} ({UserId}), Series: {SeriesTitle} ({SeriesId}), Score: {Score}",
                                message.RatingId, message.UserName, message.UserId, message.SeriesTitle, message.SeriesId, message.Score);
                            
                            // Create a scope for the scoped consumer service
                            using var scope = _serviceProvider.CreateScope();
                            var consumer = scope.ServiceProvider.GetRequiredService<ReviewCreatedEventConsumer>();
                            await consumer.HandleAsync(message, cancellationToken);
                        });
                        _logger.LogInformation("Successfully subscribed to ReviewCreatedEvent with consumer.");
                    }
                    catch (Exception ex)
                    {
                        // Log warning but continue - don't crash the hosted service
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
                            
                            // Create a scope for the scoped consumer service
                            using var scope = _serviceProvider.CreateScope();
                            var consumer = scope.ServiceProvider.GetRequiredService<EpisodeWatchedEventConsumer>();
                            await consumer.HandleAsync(message, cancellationToken);
                        });
                        _logger.LogInformation("Successfully subscribed to EpisodeWatchedEvent with consumer.");
                    }
                    catch (Exception ex)
                    {
                        // Log warning but continue - don't crash the hosted service
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
                        // Log warning but continue - don't crash the hosted service
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
                        // Log warning but continue - don't crash the hosted service
                        _logger.LogWarning(ex, "Failed to subscribe to UserUpdatedEvent. The application will continue without this subscription.");
                    }

                    _logger.LogInformation("Message bus subscription initialization completed.");
                }
                catch (OperationCanceledException)
                {
                    // Expected when cancellation token is triggered - don't log as error
                    _logger.LogInformation("Message bus subscription initialization was canceled.");
                }
                catch (Exception ex)
                {
                    // Catch-all for any unexpected errors - log but don't crash
                    _logger.LogError(ex, "Unexpected error during message bus subscription initialization. The application will continue.");
                }
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
