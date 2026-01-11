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
            _logger.LogInformation("MessageBusSubscriberHostedService is disabled. Worker service handles all RabbitMQ subscriptions.");
            return Task.CompletedTask;
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            return Task.CompletedTask;
        }
    }
}
