using SeriLovers.API.Models.DTOs;

namespace SeriLovers.API.Interfaces
{
    /// <summary>
    /// Service interface for admin statistics operations
    /// </summary>
    public interface IAdminStatisticsService
    {
        /// <summary>
        /// Gets comprehensive admin statistics including totals, top rated series, genre distribution, and monthly watching
        /// </summary>
        /// <returns>AdminStatisticsDto with all statistics</returns>
        Task<AdminStatisticsDto> GetStatisticsAsync();
    }
}

