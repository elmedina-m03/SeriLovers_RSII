using System;

namespace SeriLovers.API.Events
{
    public class SeriesUpdatedEvent
    {
        public int SeriesId { get; set; }
        public string Title { get; set; } = string.Empty;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
