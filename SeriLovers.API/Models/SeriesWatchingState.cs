using System;
using System.ComponentModel.DataAnnotations;
using SeriLovers.API.Domain;

namespace SeriLovers.API.Models
{
    public class SeriesWatchingState
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }
        public ApplicationUser User { get; set; } = null!;

        [Required]
        public int SeriesId { get; set; }
        public Series Series { get; set; } = null!;

        [Required]
        public SeriesWatchingStatus Status { get; set; } = SeriesWatchingStatus.ToWatch;

        [Required]
        public int WatchedEpisodesCount { get; set; } = 0;

        [Required]
        public int TotalEpisodesCount { get; set; } = 0;

        [Required]
        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;

        [Required]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}