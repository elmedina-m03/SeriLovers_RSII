using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    public class Watchlist
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }
        public ApplicationUser User { get; set; } = null!;

        [Required]
        public int SeriesId { get; set; }
        public Series Series { get; set; } = null!;

        public DateTime AddedAt { get; set; } = DateTime.UtcNow;
    }
}

