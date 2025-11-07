using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class WatchlistDto
    {
        [Required]
        public int Id { get; set; }
        [Required]
        public int UserId { get; set; }
        [Required]
        public int SeriesId { get; set; }
        [Required]
        [DataType(DataType.DateTime)]
        public DateTime AddedAt { get; set; }
    }

    public class WatchlistCreateDto
    {
        [Required]
        public int UserId { get; set; }

        [Required]
        public int SeriesId { get; set; }
    }
}

