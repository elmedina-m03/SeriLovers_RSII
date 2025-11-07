using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Linq;

namespace SeriLovers.API.Models
{
    public class Genre
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Name is required.")]
        [StringLength(100, ErrorMessage = "Name cannot exceed 100 characters.")]
        public string Name { get; set; } = string.Empty;
        
        // Navigation properties
        public ICollection<SeriesGenre> SeriesGenres { get; set; } = new List<SeriesGenre>();

        [NotMapped]
        public IEnumerable<Series> Series => SeriesGenres
            .Where(sg => sg.Series != null)
            .Select(sg => sg.Series!);
    }
}

