using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class SeriesDetailDto
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
        public IList<GenreDto> Genres { get; set; } = new List<GenreDto>();
        public IList<ActorDto> Actors { get; set; } = new List<ActorDto>();
        public IList<SeasonDto> Seasons { get; set; } = new List<SeasonDto>();
        public IList<RatingDto> Ratings { get; set; } = new List<RatingDto>();
        public IList<WatchlistDto> Watchlists { get; set; } = new List<WatchlistDto>();
    }
}

