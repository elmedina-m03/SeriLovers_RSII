using System;
using System.Threading;
using System.Threading.Tasks;
using EasyNetQ;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Interfaces;

namespace SeriLovers.API.Services
{
    public class MessageBusService : IMessageBusService, IDisposable
    {
        // RabbitMQ DISABLED - All functionality commented out
        // private readonly IBus _bus;
        private readonly ILogger<MessageBusService> _logger;
        private bool _disposed;

        public MessageBusService(ILogger<MessageBusService> logger)
        {
            // _bus = bus;
            _logger = logger;
        }

        public async Task PublishEventAsync<T>(T message) where T : class
        {
            // RabbitMQ DISABLED
            _logger.LogWarning("RabbitMQ is disabled. Event {EventType} will not be published.", typeof(T).Name);
            await Task.CompletedTask;
            
            // if (_bus == null)
            // {
            //     _logger.LogWarning("Cannot publish event {EventType}: RabbitMQ is not available.", typeof(T).Name);
            //     return;
            // }

            // try
            // {
            //     _logger.LogInformation("Publishing event {EventType}", typeof(T).Name);
            //     await _bus.PubSub.PublishAsync(message);
            // }
            // catch (Exception ex)
            // {
            //     _logger.LogError(ex, "Failed to publish event {EventType}", typeof(T).Name);
            //     throw;
            // }
        }

        public async Task SubscribeAsync<T>(string subscriptionId, Func<T, Task> handler) where T : class
        {
            // RabbitMQ DISABLED
            _logger.LogWarning("RabbitMQ is disabled. Cannot subscribe to {EventType}.", typeof(T).Name);
            await Task.CompletedTask;
            
            // if (_bus == null)
            // {
            //     _logger.LogWarning("Cannot subscribe to {EventType}: RabbitMQ is not available.", typeof(T).Name);
            //     throw new InvalidOperationException("RabbitMQ is not available. Cannot subscribe to events.");
            // }

            // try
            // {
            //     _logger.LogInformation("Subscribing to {EventType} with subscription {SubscriptionId}", typeof(T).Name, subscriptionId);
            //     
            //     // Use a timeout wrapper to prevent indefinite waiting
            //     using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            //     var subscriptionTask = _bus.PubSub.SubscribeAsync(subscriptionId, handler);
            //     var timeoutTask = Task.Delay(TimeSpan.FromSeconds(30), cts.Token);
            //     
            //     var completedTask = await Task.WhenAny(subscriptionTask, timeoutTask);
            //     
            //     if (completedTask == timeoutTask)
            //     {
            //         _logger.LogError("Subscription to {EventType} timed out after 30 seconds", typeof(T).Name);
            //         throw new TimeoutException($"Subscription to {typeof(T).Name} timed out. RabbitMQ may be slow to respond.");
            //     }
            //     
            //     await subscriptionTask; // Ensure any exceptions are propagated
            //     _logger.LogInformation("Successfully subscribed to {EventType}", typeof(T).Name);
            // }
            // catch (TimeoutException)
            // {
            //     throw; // Re-throw timeout exceptions
            // }
            // catch (Exception ex)
            // {
            //     _logger.LogError(ex, "Failed to subscribe to {EventType}", typeof(T).Name);
            //     throw;
            // }
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            // _bus?.Dispose();
        }
    }
}
