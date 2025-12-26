using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    /// <summary>
    /// Represents a user's review for a specific episode
    /// </summary>
    public class EpisodeReview
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }
        public ApplicationUser User { get; set; } = null!;

        [Required]
        public int EpisodeId { get; set; }
        public Episode Episode { get; set; } = null!;

        /// <summary>
        /// Star rating (1-5)
        /// </summary>
        [Required]
        [Range(1, 5, ErrorMessage = "Rating must be between 1 and 5.")]
        public int Rating { get; set; }

        /// <summary>
        /// Review text/comment
        /// </summary>
        [StringLength(2000, ErrorMessage = "Review text cannot exceed 2000 characters.")]
        public string? ReviewText { get; set; }

        /// <summary>
        /// When the review was created
        /// </summary>
        [Required]
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// When the review was last updated
        /// </summary>
        public DateTime? UpdatedAt { get; set; }

        /// <summary>
        /// Whether the review should be displayed anonymously
        /// </summary>
        public bool IsAnonymous { get; set; } = false;
    }
}

