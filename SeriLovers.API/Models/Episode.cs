using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    public class Episode
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "SeasonId is required.")]
        public int SeasonId { get; set; }

        [Required(ErrorMessage = "EpisodeNumber is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "EpisodeNumber must be greater than 0.")]
        public int EpisodeNumber { get; set; }

        [Required(ErrorMessage = "Title is required.")]
        [StringLength(200, ErrorMessage = "Title cannot exceed 200 characters.")]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000, ErrorMessage = "Description cannot exceed 2000 characters.")]
        public string? Description { get; set; }

        [DataType(DataType.Date, ErrorMessage = "AirDate must be a valid date.")]
        public DateTime? AirDate { get; set; }

        [Range(1, int.MaxValue, ErrorMessage = "DurationMinutes must be greater than 0.")]
        public int? DurationMinutes { get; set; }

        [Range(0.0, 10.0, ErrorMessage = "Rating must be between 0 and 10.")]
        public double? Rating { get; set; }
        
        // Navigation properties
        public Season Season { get; set; } = null!;
        public ICollection<EpisodeProgress> EpisodeProgresses { get; set; } = new List<EpisodeProgress>();
        public ICollection<EpisodeReview> EpisodeReviews { get; set; } = new List<EpisodeReview>();
    }
}

