using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace SeriLovers.API.Interfaces
{
    public interface ISeriesService
    {
        PagedResult<Series> GetAll(int page = 1, int pageSize = 10, int? genreId = null, double? minRating = null, string? search = null, int? year = null, string? sortBy = null, string? sortOrder = null);
        Series? GetById(int id);
        List<Series> Search(string keyword);
        void Add(Series series);
        void Update(Series series);
        void Delete(int id);
        Task<List<SeriesRecommendationDto>> GetRecommendationsAsync(int userId, int maxResults = 10);
    }
}
