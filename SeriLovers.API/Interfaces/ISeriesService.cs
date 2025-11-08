using SeriLovers.API.Models;

namespace SeriLovers.API.Interfaces
{
    public interface ISeriesService
    {
        PagedResult<Series> GetAll(int page = 1, int pageSize = 10, string? genre = null, double? minRating = null, string? search = null);
        Series? GetById(int id);
        List<Series> Search(string keyword);
        void Add(Series series);
        void Update(Series series);
        void Delete(int id);
    }
}
