using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;

namespace SeriLovers.API.Models
{
    public class Actor
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "FirstName is required.")]
        [StringLength(100, ErrorMessage = "FirstName cannot exceed 100 characters.")]
        public string FirstName { get; set; } = string.Empty;

        [Required(ErrorMessage = "LastName is required.")]
        [StringLength(100, ErrorMessage = "LastName cannot exceed 100 characters.")]
        public string LastName { get; set; } = string.Empty;

        [DataType(DataType.Date, ErrorMessage = "DateOfBirth must be a valid date.")]
        public DateTime? DateOfBirth { get; set; }

        [StringLength(2000, ErrorMessage = "Biography cannot exceed 2000 characters.")]
        public string? Biography { get; set; }

        [StringLength(500, ErrorMessage = "ImageUrl cannot exceed 500 characters.")]
        public string? ImageUrl { get; set; }
        
        // Navigation properties
        public ICollection<SeriesActor> SeriesActors { get; set; } = new List<SeriesActor>();
        public ICollection<FavoriteCharacter> FavoriteCharacters { get; set; } = new List<FavoriteCharacter>();

        [NotMapped]
        public IEnumerable<Series> Series => SeriesActors
            .Where(sa => sa.Series != null)
            .Select(sa => sa.Series!);

        // Computed property for full name
        public string FullName => $"{FirstName} {LastName}";
    }
}

