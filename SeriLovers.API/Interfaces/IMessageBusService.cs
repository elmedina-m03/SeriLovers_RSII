using System;
using System.Threading.Tasks;

namespace SeriLovers.API.Interfaces
{
    public interface IMessageBusService
    {
        bool IsAvailable { get; }
        Task PublishEventAsync<T>(T message) where T : class;
        Task SubscribeAsync<T>(string subscriptionId, Func<T, Task> handler) where T : class;
    }
}
