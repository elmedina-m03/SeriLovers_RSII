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

            // Start subscriptions in the background to avoid blocking application startup
            // Use Task.Run to ensure subscriptions don't block the startup process
            _ = Task.Run(async () =>
            {
                // Add a small delay to ensure RabbitMQ connection is fully established
                await Task.Delay(TimeSpan.FromSeconds(2), cancellationToken);

                // Wrap each subscription individually so one failure doesn't prevent others
                try
                {
                    await _messageBusService.SubscribeAsync<SeriesUpdatedEvent>("SeriesUpdatedHandler", async message =>
                    {
                        _logger.LogInformation("Received SeriesUpdatedEvent for SeriesId {SeriesId}", message.SeriesId);
                        await Task.CompletedTask;
                    });
                    _logger.LogInformation("Successfully subscribed to SeriesUpdatedEvent.");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to subscribe to SeriesUpdatedEvent. The application will continue without this subscription.");
                }

                try
                {
                    await _messageBusService.SubscribeAsync<ActorCreatedEvent>("ActorCreatedHandler", async message =>
                    {
                        _logger.LogInformation("Received ActorCreatedEvent for ActorId {ActorId}", message.ActorId);
                        await Task.CompletedTask;
                    });
                    _logger.LogInformation("Successfully subscribed to ActorCreatedEvent.");
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to subscribe to ActorCreatedEvent. The application will continue without this subscription.");
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
