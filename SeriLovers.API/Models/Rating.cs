using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    public class Rating
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }
        public ApplicationUser User { get; set; } = null!;

        [Required]
        public int SeriesId { get; set; }
        public Series Series { get; set; } = null!;

        [Required]
        [Range(1, 10, ErrorMessage = "Score must be between 1 and 10.")]
        public int Score { get; set; }

        [StringLength(2000, ErrorMessage = "Comment cannot exceed 2000 characters.")]
        public string? Comment { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}

