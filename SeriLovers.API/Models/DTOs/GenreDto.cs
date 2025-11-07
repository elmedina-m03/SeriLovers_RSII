using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class GenreDto
    {
        [Required]
        public int Id { get; set; }
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;
    }

    public class GenreUpsertDto
    {
        [Required]
        [StringLength(100)]
        public string Name { get; set; } = string.Empty;
    }
}

