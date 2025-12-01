using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    /// <summary>
    /// Tracks which episodes a user has watched
    /// </summary>
    public class EpisodeProgress
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }
        public ApplicationUser User { get; set; } = null!;

        [Required]
        public int EpisodeId { get; set; }
        public Episode Episode { get; set; } = null!;

        /// <summary>
        /// When the user watched this episode
        /// </summary>
        [Required]
        public DateTime WatchedAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Whether the user has completed watching this episode (vs just started)
        /// </summary>
        public bool IsCompleted { get; set; } = true;
    }
}

