using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    /// <summary>
    /// Represents a viewing event when a user watches a series
    /// Used for tracking monthly watching statistics and view counts
    /// </summary>
    public class ViewingEvent
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }

        [Required]
        public int SeriesId { get; set; }

        [Required]
        public DateTime ViewedAt { get; set; } = DateTime.UtcNow;

        // Navigation properties
        public ApplicationUser? User { get; set; }
        public Series? Series { get; set; }
    }
}

