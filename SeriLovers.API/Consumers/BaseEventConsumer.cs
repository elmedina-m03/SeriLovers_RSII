using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace SeriLovers.API.Consumers
{
    /// <summary>
    /// Base class for event consumers with retry logic and logging
    /// </summary>
    public abstract class BaseEventConsumer
    {
        protected readonly ILogger _logger;
        protected const int MaxRetries = 3;
        protected const int BaseDelaySeconds = 2;

        protected BaseEventConsumer(ILogger logger)
        {
            _logger = logger;
        }

        /// <summary>
        /// Executes an action with retry logic and exponential backoff
        /// </summary>
        protected async Task<T> ExecuteWithRetryAsync<T>(
            Func<Task<T>> action,
            string operationName,
            CancellationToken cancellationToken = default)
        {
            Exception? lastException = null;

            for (int attempt = 1; attempt <= MaxRetries; attempt++)
            {
                try
                {
                    _logger.LogDebug(
                        "Executing {OperationName} (attempt {Attempt}/{MaxRetries})",
                        operationName, attempt, MaxRetries);

                    var result = await action();
                    
                    if (attempt > 1)
                    {
                        _logger.LogInformation(
                            "{OperationName} succeeded on attempt {Attempt}",
                            operationName, attempt);
                    }

                    return result;
                }
                catch (Exception ex)
                {
                    lastException = ex;
                    
                    _logger.LogWarning(
                        ex,
                        "{OperationName} failed on attempt {Attempt}/{MaxRetries}: {ErrorMessage}",
                        operationName, attempt, MaxRetries, ex.Message);

                    if (attempt < MaxRetries)
                    {
                        var delaySeconds = CalculateBackoffDelay(attempt);
                        _logger.LogInformation(
                            "Retrying {OperationName} after {DelaySeconds} seconds...",
                            operationName, delaySeconds);
                        
                        await Task.Delay(TimeSpan.FromSeconds(delaySeconds), cancellationToken);
                    }
                }
            }

            _logger.LogError(
                lastException,
                "{OperationName} failed after {MaxRetries} attempts",
                operationName, MaxRetries);

            throw new InvalidOperationException(
                $"{operationName} failed after {MaxRetries} attempts", 
                lastException);
        }

        /// <summary>
        /// Executes an action with retry logic (void version)
        /// </summary>
        protected async Task ExecuteWithRetryAsync(
            Func<Task> action,
            string operationName,
            CancellationToken cancellationToken = default)
        {
            await ExecuteWithRetryAsync(async () =>
            {
                await action();
                return true;
            }, operationName, cancellationToken);
        }

        /// <summary>
        /// Calculates exponential backoff delay
        /// </summary>
        private int CalculateBackoffDelay(int attempt)
        {
            // Exponential backoff: 2^attempt * baseDelay, with a max of 30 seconds
            var delay = (int)(Math.Pow(2, attempt - 1) * BaseDelaySeconds);
            return Math.Min(delay, 30);
        }
    }
}

