using SeriLovers.API.Models;

namespace SeriLovers.API.Interfaces
{
    public interface IGenreService
    {
        List<Genre> GetAll();
        Genre? GetById(int id);
        void Add(Genre genre);
        void Update(Genre genre);
        void Delete(int id);
    }
}
