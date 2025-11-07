using SeriLovers.API.Models;

namespace SeriLovers.API.Interfaces
{
    public interface ISeriesService
    {
        List<Series> GetAll();
        Series? GetById(int id);
        List<Series> Search(string keyword);
        void Add(Series series);
        void Update(Series series);
        void Delete(int id);
    }
}
