using System;
using System.Threading;
using System.Threading.Tasks;
using EasyNetQ;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Interfaces;

namespace SeriLovers.API.Services
{
    public class MessageBusService : IMessageBusService, IDisposable
    {
        private readonly IBus? _bus;
        private readonly ILogger<MessageBusService> _logger;
        private readonly IHostEnvironment _hostEnvironment;
        private bool _disposed;

        public bool IsAvailable => _bus != null;

        public MessageBusService(IBus? bus, ILogger<MessageBusService> logger, IHostEnvironment hostEnvironment)
        {
            _bus = bus;
            _logger = logger;
            _hostEnvironment = hostEnvironment;
        }

        public Task PublishEventAsync<T>(T message) where T : class
        {
            if (_bus == null)
            {
                _logger.LogDebug("Cannot publish event {EventType}: RabbitMQ is not available.", typeof(T).Name);
                return Task.CompletedTask;
            }

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
            return Task.CompletedTask;
        }

        public async Task SubscribeAsync<T>(string subscriptionId, Func<T, Task> handler) where T : class
        {
            if (_bus == null)
            {
                _logger.LogDebug("Skipping subscription to {EventType}: RabbitMQ is not available.", typeof(T).Name);
                return; // Return gracefully instead of throwing
            }

            // In Development environment, skip retries and fail gracefully
            // but we handle it defensively here as well
            if (_hostEnvironment.IsDevelopment())
            {
                // In Development: single attempt, no retries, fail gracefully, non-blocking
                // Use fire-and-forget pattern to avoid blocking startup
                _ = Task.Run(async () =>
                {
                    try
                    {
                        _logger.LogInformation("Subscribing to {EventType} with subscription {SubscriptionId} (Development mode - single attempt)", 
                            typeof(T).Name, subscriptionId);
                        
                        // Use a shorter timeout in Development
                        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                        
                        var subscription = await _bus.PubSub.SubscribeAsync(subscriptionId, handler);
                        _logger.LogInformation("Successfully subscribed to {EventType}", typeof(T).Name);
                    }
                    catch (TaskCanceledException)
                    {
                        // In Development: log and continue without subscription (no exception bubbling)
                        _logger.LogWarning("Subscription to {EventType} was canceled in Development. Skipping subscription.", typeof(T).Name);
                    }
                    catch (Exception ex)
                    {
                        // In Development: log single warning and continue (no exception bubbling)
                        _logger.LogWarning(ex, "Failed to subscribe to {EventType} in Development. The application will continue without this subscription.", typeof(T).Name);
                    }
                }, CancellationToken.None);
                
                // Return immediately in Development - don't wait for subscription
                return;
            }
            
            // Production: retry logic with proper error handling and cancellation support
            const int maxRetries = 3;
            const int baseDelaySeconds = 2;
            const int timeoutSeconds = 30; // Reasonable timeout for Production
            
            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    _logger.LogInformation("Subscribing to {EventType} with subscription {SubscriptionId} (attempt {Attempt}/{MaxRetries})", 
                        typeof(T).Name, subscriptionId, attempt, maxRetries);
                    
                    // Use a timeout wrapper to prevent indefinite waiting
                    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeoutSeconds));
                    
                    // Subscribe with cancellation token support
                    var subscription = await _bus.PubSub.SubscribeAsync(subscriptionId, handler);
                    
                    _logger.LogInformation("Successfully subscribed to {EventType}", typeof(T).Name);
                    return; // Success - exit retry loop
                }
                catch (TaskCanceledException)
                {
                    // Suppress TaskCanceledException spam - log only once per subscription
                    if (attempt < maxRetries)
                    {
                        var delaySeconds = baseDelaySeconds * attempt;
                        _logger.LogDebug("Subscription to {EventType} was canceled (attempt {Attempt}/{MaxRetries}). Retrying after {DelaySeconds} seconds...", 
                            typeof(T).Name, attempt, maxRetries, delaySeconds);
                        
                        // Use CancellationToken.None to ensure delay completes even if original token is canceled
                        await Task.Delay(TimeSpan.FromSeconds(delaySeconds), CancellationToken.None);
                        continue;
                    }
                    
                    // Last attempt failed - log warning but don't throw to avoid startup blocking
                    _logger.LogWarning("Subscription to {EventType} was canceled after {MaxRetries} attempts. RabbitMQ connection may be unstable.", 
                        typeof(T).Name, maxRetries);
                    return; // Fail gracefully in Production too
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
                        
                        // Use CancellationToken.None to ensure delay completes
                        await Task.Delay(TimeSpan.FromSeconds(delaySeconds), CancellationToken.None);
                        continue;
                    }
                    
                    // Last attempt failed - log error but return gracefully to avoid blocking startup
                    _logger.LogError(ex, "Failed to subscribe to {EventType} after {MaxRetries} attempts. The application will continue without this subscription.", 
                        typeof(T).Name, maxRetries);
                    return; // Fail gracefully instead of throwing
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
