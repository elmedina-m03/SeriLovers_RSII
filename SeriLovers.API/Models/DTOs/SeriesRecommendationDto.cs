using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class SeriesRecommendationDto
    {
        [Required]
        public string Title { get; set; } = string.Empty;

        [Required]
        public IList<string> Genres { get; set; } = new List<string>();

        [Range(0.0, 10.0)]
        public double AverageRating { get; set; }
    }
}
