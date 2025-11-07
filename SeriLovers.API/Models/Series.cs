using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    public class Series
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Title is required.")]
        [StringLength(200, ErrorMessage = "Title cannot exceed 200 characters.")]
        public string Title { get; set; } = string.Empty;

        [StringLength(2000, ErrorMessage = "Description cannot exceed 2000 characters.")]
        public string Description { get; set; } = string.Empty;

        [Required(ErrorMessage = "ReleaseDate is required.")]
        [DataType(DataType.Date, ErrorMessage = "ReleaseDate must be a valid date.")]
        public DateTime ReleaseDate { get; set; }

        [Required(ErrorMessage = "Rating is required.")]
        [Range(0.0, 10.0, ErrorMessage = "Rating must be between 0 and 10.")]
        public double Rating { get; set; }

        [StringLength(100, ErrorMessage = "Genre cannot exceed 100 characters.")]
        public string Genre { get; set; } = string.Empty;
        
        // Navigation properties
        public ICollection<Season> Seasons { get; set; } = new List<Season>();
        public ICollection<Genre> Genres { get; set; } = new List<Genre>();
        public ICollection<Actor> Actors { get; set; } = new List<Actor>();
    }
}
