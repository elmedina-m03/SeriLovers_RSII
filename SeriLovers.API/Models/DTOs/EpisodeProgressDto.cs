using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class EpisodeProgressDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string? UserName { get; set; }
        public int EpisodeId { get; set; }
        public string? EpisodeTitle { get; set; }
        public int EpisodeNumber { get; set; }
        public int SeasonId { get; set; }
        public int SeasonNumber { get; set; }
        public int SeriesId { get; set; }
        public string? SeriesTitle { get; set; }
        public DateTime WatchedAt { get; set; }
        public bool IsCompleted { get; set; }
    }

    public class EpisodeProgressCreateDto
    {
        [Required]
        public int EpisodeId { get; set; }

        public bool IsCompleted { get; set; } = true;
    }

    public class SeriesProgressDto
    {
        public int SeriesId { get; set; }
        public string? SeriesTitle { get; set; }
        public int TotalEpisodes { get; set; }
        public int WatchedEpisodes { get; set; }
        public int CurrentEpisodeNumber { get; set; }
        public int CurrentSeasonNumber { get; set; }
        public double ProgressPercentage { get; set; }
    }
}

