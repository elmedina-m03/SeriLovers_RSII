using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class EpisodeDto
    {
        [Required]
        public int Id { get; set; }

        [Required]
        [Range(1, int.MaxValue)]
        public int EpisodeNumber { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000)]
        public string? Description { get; set; }
        [DataType(DataType.Date)]
        public DateTime? AirDate { get; set; }
        [Range(1, int.MaxValue)]
        public int? DurationMinutes { get; set; }
        [Range(0.0, 10.0)]
        public double? Rating { get; set; }
    }

    public class EpisodeUpsertDto
    {
        [Required]
        public int SeasonId { get; set; }

        [Required]
        [Range(1, int.MaxValue)]
        public int EpisodeNumber { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000)]
        public string? Description { get; set; }

        [DataType(DataType.Date)]
        public DateTime? AirDate { get; set; }

        [Range(1, int.MaxValue)]
        public int? DurationMinutes { get; set; }

        [Range(0.0, 10.0)]
        public double? Rating { get; set; }
    }
}

