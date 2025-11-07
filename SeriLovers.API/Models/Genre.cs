using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    public class Genre
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Name is required.")]
        [StringLength(100, ErrorMessage = "Name cannot exceed 100 characters.")]
        public string Name { get; set; } = string.Empty;
        
        // Many-to-many relationship with Series
        public ICollection<Series> Series { get; set; } = new List<Series>();
    }
}

