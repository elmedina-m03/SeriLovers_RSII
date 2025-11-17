using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SeriLovers.API.Models
{
    public class RecommendationLog
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        public ApplicationUser? User { get; set; }

        [Required]
        public int SeriesId { get; set; }

        [ForeignKey(nameof(SeriesId))]
        public Series? Series { get; set; }

        public DateTime RecommendedAt { get; set; } = DateTime.UtcNow;

        public bool Watched { get; set; }
    }
}
