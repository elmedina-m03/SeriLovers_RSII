using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class SeasonDto
    {
        [Required]
        public int Id { get; set; }

        [Required]
        [Range(1, int.MaxValue)]
        public int SeasonNumber { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000)]
        public string? Description { get; set; }
        [DataType(DataType.Date)]
        public DateTime? ReleaseDate { get; set; }

        [Required]
        public IList<EpisodeDto> Episodes { get; set; } = new List<EpisodeDto>();
    }

    public class SeasonUpsertDto
    {
        [Required]
        public int SeriesId { get; set; }

        [Required]
        [Range(1, int.MaxValue)]
        public int SeasonNumber { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000)]
        public string? Description { get; set; }

        [DataType(DataType.Date)]
        public DateTime? ReleaseDate { get; set; }
    }
}

