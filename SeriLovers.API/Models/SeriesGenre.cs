namespace SeriLovers.API.Models
{
    public class SeriesGenre
    {
        public int SeriesId { get; set; }
        public Series Series { get; set; } = null!;

        public int GenreId { get; set; }
        public Genre Genre { get; set; } = null!;
    }
}

