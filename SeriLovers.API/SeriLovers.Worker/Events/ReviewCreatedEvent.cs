using System;

namespace SeriLovers.API.Events
{
    public class ReviewCreatedEvent
    {
        public int RatingId { get; set; }
        public int UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public int SeriesId { get; set; }
        public string SeriesTitle { get; set; } = string.Empty;
        public int Score { get; set; }
        public string? Comment { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}

