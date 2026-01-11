using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    /// <summary>
    /// Represents a user's reminder preference for a series.
    /// When enabled, the user will be notified when new episodes are added.
    /// </summary>
    public class UserSeriesReminder
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }
        public ApplicationUser User { get; set; } = null!;

        [Required]
        public int SeriesId { get; set; }
        public Series Series { get; set; } = null!;

        /// <summary>
        /// Last episode count when reminder was enabled or last checked
        /// Used to detect when new episodes are added
        /// </summary>
        public int LastEpisodeCount { get; set; }

        public DateTime EnabledAt { get; set; } = DateTime.UtcNow;

        public DateTime? LastCheckedAt { get; set; }

        // Unique constraint: one reminder per user per series
    }
}

