using System.ComponentModel.DataAnnotations;

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
        
        // Many-to-many relationship with Series
        public ICollection<Series> Series { get; set; } = new List<Series>();
        
        // Computed property for full name
        public string FullName => $"{FirstName} {LastName}";
    }
}

