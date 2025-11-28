using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class ActorDto
    {
        [Required]
        public int Id { get; set; }

        [Required]
        [StringLength(100)]
        public string FirstName { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        public string LastName { get; set; } = string.Empty;

        [Required]
        public string FullName { get; set; } = string.Empty;

        public DateTime? DateOfBirth { get; set; }

        public int? Age { get; set; }

        public int SeriesCount { get; set; }

        [StringLength(500)]
        public string? ImageUrl { get; set; }
    }

    public class ActorUpsertDto
    {
        [Required]
        [StringLength(100)]
        public string FirstName { get; set; } = string.Empty;

        [Required]
        [StringLength(100)]
        public string LastName { get; set; } = string.Empty;

        [DataType(DataType.Date)]
        public DateTime? DateOfBirth { get; set; }

        [StringLength(2000)]
        public string? Biography { get; set; }

        [StringLength(500)]
        public string? ImageUrl { get; set; }
    }
}
