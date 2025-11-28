using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class SeriesDto
    {
        [Required]
        public int Id { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000)]
        public string? Description { get; set; }

        [Required]
        [DataType(DataType.Date)]
        public DateTime ReleaseDate { get; set; }

        [Required]
        [Range(0.0, 10.0)]
        public double Rating { get; set; }

        [Required]
        public IList<string> Genres { get; set; } = new List<string>();

        [Required]
        public IList<ActorDto> Actors { get; set; } = new List<ActorDto>();

        [Required]
        [Range(0, int.MaxValue)]
        public int RatingsCount { get; set; }

        [Required]
        [Range(0, int.MaxValue)]
        public int WatchlistsCount { get; set; }

        [StringLength(500)]
        public string? ImageUrl { get; set; }
    }
}

