using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    public class SeriesActor
    {
        public int SeriesId { get; set; }
        public Series Series { get; set; } = null!;

        public int ActorId { get; set; }
        public Actor Actor { get; set; } = null!;

        [StringLength(150, ErrorMessage = "Role name cannot exceed 150 characters.")]
        public string? RoleName { get; set; }
    }
}

