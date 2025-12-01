using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class EpisodeReviewDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string? UserName { get; set; }
        public string? UserAvatarUrl { get; set; }
        public int EpisodeId { get; set; }
        public string? EpisodeTitle { get; set; }
        public int EpisodeNumber { get; set; }
        public int SeasonId { get; set; }
        public int SeasonNumber { get; set; }
        public int SeriesId { get; set; }
        public string? SeriesTitle { get; set; }
        public int Rating { get; set; }
        public string? ReviewText { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }

    public class EpisodeReviewCreateDto
    {
        [Required]
        public int EpisodeId { get; set; }

        [Required]
        [Range(1, 5, ErrorMessage = "Rating must be between 1 and 5.")]
        public int Rating { get; set; }

        [StringLength(2000, ErrorMessage = "Review text cannot exceed 2000 characters.")]
        public string? ReviewText { get; set; }
    }

    public class EpisodeReviewUpdateDto
    {
        [Required]
        [Range(1, 5, ErrorMessage = "Rating must be between 1 and 5.")]
        public int Rating { get; set; }

        [StringLength(2000, ErrorMessage = "Review text cannot exceed 2000 characters.")]
        public string? ReviewText { get; set; }
    }
}

