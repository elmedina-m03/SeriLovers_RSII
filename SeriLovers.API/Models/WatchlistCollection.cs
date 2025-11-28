using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    /// <summary>
    /// Represents a custom watchlist collection (e.g., "MySummerList", "Save for later")
    /// </summary>
    public class WatchlistCollection
    {
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        [Required]
        public int UserId { get; set; }
        public ApplicationUser User { get; set; } = null!;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property for watchlist items in this collection
        public ICollection<Watchlist> Watchlists { get; set; } = new List<Watchlist>();
    }
}

