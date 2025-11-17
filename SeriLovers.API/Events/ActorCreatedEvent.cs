using System;

namespace SeriLovers.API.Events
{
    public class ActorCreatedEvent
    {
        public int ActorId { get; set; }
        public string FirstName { get; set; } = string.Empty;
        public string LastName { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
