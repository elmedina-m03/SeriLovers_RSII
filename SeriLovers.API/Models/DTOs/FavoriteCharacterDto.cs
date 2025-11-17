using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class FavoriteCharacterDto
    {
        public int Id { get; set; }

        public int UserId { get; set; }

        public int ActorId { get; set; }

        public string? ActorName { get; set; }

        public int SeriesId { get; set; }

        public string? SeriesTitle { get; set; }

        public DateTime CreatedAt { get; set; }
    }
}
