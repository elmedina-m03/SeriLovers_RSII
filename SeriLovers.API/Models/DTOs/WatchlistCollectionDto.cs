using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class WatchlistCollectionDto
    {
        [Required]
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        [StringLength(500)]
        public string? CoverUrl { get; set; }

        [StringLength(50)]
        public string? Category { get; set; }

        [StringLength(50)]
        public string? Status { get; set; }

        [Required]
        public int UserId { get; set; }

        [Required]
        public DateTime CreatedAt { get; set; }

        /// <summary>
        /// Number of series in this collection
        /// </summary>
        public int SeriesCount { get; set; }
    }

    public class WatchlistCollectionCreateDto
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;

        [StringLength(500)]
        public string? Description { get; set; }

        [StringLength(500)]
        public string? CoverUrl { get; set; }

        [StringLength(50)]
        public string? Category { get; set; }

        [StringLength(50)]
        public string? Status { get; set; }
    }

    public class WatchlistCollectionUpdateDto
    {
        [StringLength(100)]
        public string? Name { get; set; }

        [StringLength(500)]
        public string? Description { get; set; }

        [StringLength(500)]
        public string? CoverUrl { get; set; }

        [StringLength(50)]
        public string? Category { get; set; }

        [StringLength(50)]
        public string? Status { get; set; }
    }

    public class WatchlistCollectionDetailDto : WatchlistCollectionDto
    {
        /// <summary>
        /// List of series in this collection
        /// </summary>
        public IList<WatchlistDto> Watchlists { get; set; } = new List<WatchlistDto>();
    }
}

