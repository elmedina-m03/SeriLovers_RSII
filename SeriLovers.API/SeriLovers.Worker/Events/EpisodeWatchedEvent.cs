using System;

namespace SeriLovers.API.Events
{
    public class EpisodeWatchedEvent
    {
        public int EpisodeId { get; set; }
        public int EpisodeNumber { get; set; }
        public int SeasonId { get; set; }
        public int SeasonNumber { get; set; }
        public int SeriesId { get; set; }
        public string SeriesTitle { get; set; } = string.Empty;
        public int UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public bool IsCompleted { get; set; }
        public DateTime WatchedAt { get; set; } = DateTime.UtcNow;
    }
}

