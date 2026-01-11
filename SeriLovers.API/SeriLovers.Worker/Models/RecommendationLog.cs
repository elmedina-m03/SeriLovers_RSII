using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SeriLovers.Worker.Models
{
    public class RecommendationLog
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }

        [Required]
        public int SeriesId { get; set; }

        public DateTime RecommendedAt { get; set; } = DateTime.UtcNow;

        public bool Watched { get; set; }
    }
}

