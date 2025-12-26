using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class SeriesRecommendationDto
    {
        public int Id { get; set; }

        [Required]
        public string Title { get; set; } = string.Empty;

        public string? ImageUrl { get; set; }

        [Required]
        public IList<string> Genres { get; set; } = new List<string>();

        [Range(0.0, 10.0)]
        public double AverageRating { get; set; }

        /// <summary>
        /// Similarity score (0.0 to 1.0) indicating how well the series matches user preferences
        /// </summary>
        [Range(0.0, 1.0)]
        public double SimilarityScore { get; set; }

        /// <summary>
        /// Human-readable reason for the recommendation
        /// </summary>
        public string? Reason { get; set; }
    }
}
