using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class RatingDto
    {
        [Required]
        public int Id { get; set; }
        [Required]
        public int UserId { get; set; }
        [Required]
        public int SeriesId { get; set; }
        [Required]
        [Range(1, 10)]
        public int Score { get; set; }
        [StringLength(2000)]
        public string? Comment { get; set; }
        [Required]
        [DataType(DataType.DateTime)]
        public DateTime CreatedAt { get; set; }
        
        // Additional fields for admin panel display
        public string? UserName { get; set; }
        public string? UserEmail { get; set; }
        public string? UserAvatarUrl { get; set; }
        public string? SeriesTitle { get; set; }
        public string? SeriesImageUrl { get; set; }
    }

    public class RatingCreateDto
    {
        [Required]
        public int SeriesId { get; set; }

        [Required]
        [Range(1, 10)]
        public int Score { get; set; }

        [StringLength(2000)]
        public string? Comment { get; set; }
    }

    public class RatingUpdateDto
    {
        [Required]
        [Range(1, 10)]
        public int Score { get; set; }

        [StringLength(2000)]
        public string? Comment { get; set; }
    }
}

