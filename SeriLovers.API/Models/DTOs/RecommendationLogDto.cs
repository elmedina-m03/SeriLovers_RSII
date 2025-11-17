using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class RecommendationLogDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string? UserEmail { get; set; }
        public int SeriesId { get; set; }
        public string? SeriesTitle { get; set; }
        public DateTime RecommendedAt { get; set; }
        public bool Watched { get; set; }
    }

    public class RecommendationLogCreateDto
    {
        [Required]
        public int SeriesId { get; set; }

        public bool Watched { get; set; }
    }

    public class RecommendationLogUpdateDto
    {
        [Required]
        public bool Watched { get; set; }
    }
}
