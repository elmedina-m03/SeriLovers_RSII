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
        private readonly IBus? _bus;
        private readonly ILogger<MessageBusService> _logger;
        private bool _disposed;

        public bool IsAvailable => _bus != null;

        public MessageBusService(IBus? bus, ILogger<MessageBusService> logger)
        {
            _bus = bus;
            _logger = logger;
        }

        public Task PublishEventAsync<T>(T message) where T : class
        {
            if (_bus == null)
            {
                _logger.LogDebug("Cannot publish event {EventType}: RabbitMQ is not available.", typeof(T).Name);
                return Task.CompletedTask;
            }

            // Fire-and-forget: Don't block the request waiting for RabbitMQ
            // If RabbitMQ is slow or unavailable, we don't want to impact the main request
            _ = Task.Run(async () =>
            {
                const int maxRetries = 2;
                const int timeoutSeconds = 10; // Shorter timeout since this is fire-and-forget
                
                for (int attempt = 1; attempt <= maxRetries; attempt++)
                {
                    try
                    {
                        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeoutSeconds));
                        await _bus.PubSub.PublishAsync(message, cts.Token);
                        
                        _logger.LogDebug("Successfully published event {EventType}", typeof(T).Name);
                        return; // Success
                    }
                    catch (TaskCanceledException)
                    {
                        // Timeout or cancellation - this is expected if RabbitMQ is slow
                        if (attempt < maxRetries)
                        {
                            await Task.Delay(TimeSpan.FromSeconds(attempt), CancellationToken.None);
                            continue;
                        }
                        
                        // Log at Debug level since this is expected when RabbitMQ is unavailable
                        _logger.LogDebug("Event {EventType} publish was canceled after {MaxRetries} attempts. This is non-critical.", 
                            typeof(T).Name, maxRetries);
                        return;
                    }
                    catch (Exception ex)
                    {
                        // Only log errors at Warning level for unexpected exceptions
                        if (attempt < maxRetries)
                        {
                            _logger.LogDebug(ex, "Event {EventType} publish failed (attempt {Attempt}/{MaxRetries}), retrying...", 
                                typeof(T).Name, attempt, maxRetries);
                            await Task.Delay(TimeSpan.FromSeconds(attempt), CancellationToken.None);
                            continue;
                        }
                        
                        // Log at Debug level for expected failures (RabbitMQ unavailable)
                        _logger.LogDebug(ex, "Event {EventType} publish failed after {MaxRetries} attempts. This is non-critical.", 
                            typeof(T).Name, maxRetries);
                        return;
                    }
                }
            });
            
            // Return immediately - don't wait for publish to complete
            // This ensures the main request flow is not blocked by RabbitMQ
            return Task.CompletedTask;
        }

        public async Task SubscribeAsync<T>(string subscriptionId, Func<T, Task> handler) where T : class
        {
            if (_bus == null)
            {
                _logger.LogDebug("Skipping subscription to {EventType}: RabbitMQ is not available.", typeof(T).Name);
                return; // Return gracefully instead of throwing
            }

            const int maxRetries = 3;
            const int baseDelaySeconds = 2;
            
            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    _logger.LogInformation("Subscribing to {EventType} with subscription {SubscriptionId} (attempt {Attempt}/{MaxRetries})", 
                        typeof(T).Name, subscriptionId, attempt, maxRetries);
                    
                    // Use a timeout wrapper to prevent indefinite waiting (longer timeout for RabbitMQ operations)
                    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(60));
                    
                    // Subscribe without cancellation token (EasyNetQ doesn't support it)
                    // Wrap the subscription in a task with timeout to prevent indefinite waiting
                    var subscriptionTask = Task.Run(async () =>
                    {
                        // Start the subscription
                        var subscription = await _bus.PubSub.SubscribeAsync(subscriptionId, handler);
                        return subscription;
                    });
                    
                    var timeoutTask = Task.Delay(TimeSpan.FromSeconds(60), cts.Token);
                    var completedTask = await Task.WhenAny(subscriptionTask, timeoutTask);
                    
                    if (completedTask == timeoutTask)
                    {
                        _logger.LogWarning("Subscription to {EventType} timed out after 60 seconds (attempt {Attempt}/{MaxRetries})", 
                            typeof(T).Name, attempt, maxRetries);
                        
                        if (attempt < maxRetries)
                        {
                            var delaySeconds = baseDelaySeconds * attempt;
                            _logger.LogInformation("Retrying subscription to {EventType} after {DelaySeconds} seconds...", 
                                typeof(T).Name, delaySeconds);
                            await Task.Delay(TimeSpan.FromSeconds(delaySeconds), CancellationToken.None);
                            continue;
                        }
                        
                        throw new TimeoutException($"Subscription to {typeof(T).Name} timed out after {maxRetries} attempts. RabbitMQ may be slow to respond.");
                    }
                    
                    // Subscription completed - await it to propagate any exceptions
                    await subscriptionTask;
                    
                    _logger.LogInformation("Successfully subscribed to {EventType}", typeof(T).Name);
                    return; // Success - exit retry loop
                }
                catch (TaskCanceledException ex)
                {
                    _logger.LogWarning(ex, "Subscription to {EventType} was canceled (attempt {Attempt}/{MaxRetries}). This may indicate RabbitMQ connection issues.", 
                        typeof(T).Name, attempt, maxRetries);
                    
                    if (attempt < maxRetries)
                    {
                        var delaySeconds = baseDelaySeconds * attempt;
                        _logger.LogInformation("Retrying subscription to {EventType} after {DelaySeconds} seconds...", 
                            typeof(T).Name, delaySeconds);
                        await Task.Delay(TimeSpan.FromSeconds(delaySeconds), CancellationToken.None);
                        continue;
                    }
                    
                    throw new TimeoutException($"Subscription to {typeof(T).Name} was canceled after {maxRetries} attempts. RabbitMQ connection may be unstable.", ex);
                }
                catch (TimeoutException)
                {
                    // Already handled in the timeout check above, but re-throw if we've exhausted retries
                    throw;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to subscribe to {EventType} (attempt {Attempt}/{MaxRetries})", 
                        typeof(T).Name, attempt, maxRetries);
                    
                    if (attempt < maxRetries)
                    {
                        var delaySeconds = baseDelaySeconds * attempt;
                        _logger.LogInformation("Retrying subscription to {EventType} after {DelaySeconds} seconds...", 
                            typeof(T).Name, delaySeconds);
                        await Task.Delay(TimeSpan.FromSeconds(delaySeconds), CancellationToken.None);
                        continue;
                    }
                    
                    throw; // Re-throw on last attempt
                }
            }
        }

        public void Dispose()
        {
            if (_disposed)
            {
                return;
            }

            _disposed = true;
            _bus?.Dispose();
        }
    }
}
