using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    public class Season
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "SeriesId is required.")]
        public int SeriesId { get; set; }

        [Required(ErrorMessage = "SeasonNumber is required.")]
        [Range(1, int.MaxValue, ErrorMessage = "SeasonNumber must be greater than 0.")]
        public int SeasonNumber { get; set; }

        [Required(ErrorMessage = "Title is required.")]
        [StringLength(200, ErrorMessage = "Title cannot exceed 200 characters.")]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000, ErrorMessage = "Description cannot exceed 2000 characters.")]
        public string? Description { get; set; }

        [DataType(DataType.Date, ErrorMessage = "ReleaseDate must be a valid date.")]
        public DateTime? ReleaseDate { get; set; }
        
        // Navigation properties
        public Series Series { get; set; } = null!;
        public ICollection<Episode> Episodes { get; set; } = new List<Episode>();
    }
}

