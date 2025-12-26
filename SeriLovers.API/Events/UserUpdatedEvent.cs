using System;

namespace SeriLovers.API.Events
{
    public class UserUpdatedEvent
    {
        public int UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? Country { get; set; }
        public string? AvatarUrl { get; set; }
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}

