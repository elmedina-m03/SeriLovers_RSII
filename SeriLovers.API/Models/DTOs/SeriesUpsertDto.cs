using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class SeriesUpsertDto
    {
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
        public IList<int> GenreIds { get; set; } = new List<int>();

        [Required]
        public IList<SeriesActorInputDto> Actors { get; set; } = new List<SeriesActorInputDto>();
    }

    public class SeriesActorInputDto
    {
        [Required]
        public int ActorId { get; set; }

        [StringLength(150)]
        public string? RoleName { get; set; }
    }
}

