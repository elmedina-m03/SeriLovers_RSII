using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class FavoriteCharacterCreateDto
    {
        [Required]
        public int ActorId { get; set; }

        [Required]
        public int SeriesId { get; set; }
    }

    public class FavoriteCharacterUpdateDto : FavoriteCharacterCreateDto
    {
    }
}
