using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SeriLovers.API.Models
{
    public class FavoriteCharacter
    {
        public int Id { get; set; }

        [Required]
        public int UserId { get; set; }

        [ForeignKey(nameof(UserId))]
        public ApplicationUser? User { get; set; }

        [Required]
        public int ActorId { get; set; }

        [ForeignKey(nameof(ActorId))]
        public Actor? Actor { get; set; }

        [Required]
        public int SeriesId { get; set; }

        [ForeignKey(nameof(SeriesId))]
        public Series? Series { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
