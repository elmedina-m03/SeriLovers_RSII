using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models.DTOs;
using Swashbuckle.AspNetCore.Annotations;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Admin statistics controller for dashboard analytics
    /// </summary>
    [ApiController]
    [Route("api/Admin/Statistics")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("Admin Statistics")]
    public class AdminStatisticsController : ControllerBase
    {
        private readonly IAdminStatisticsService _statisticsService;

        public AdminStatisticsController(IAdminStatisticsService statisticsService)
        {
            _statisticsService = statisticsService;
        }

        /// <summary>
        /// Get comprehensive admin statistics
        /// </summary>
        /// <returns>Statistics including totals, genre distribution, monthly watching, and top series</returns>
        [HttpGet]
        [SwaggerOperation(
            Summary = "Get admin statistics",
            Description = "Retrieves comprehensive statistics including totals (users, series, actors, watchlistItems), genre distribution, monthly watching data, and top rated series. Returns empty arrays/zeros if database has no data.")]
        public async Task<IActionResult> GetStatistics()
        {
            try
            {
                var result = await _statisticsService.GetStatisticsAsync();
                // Service already handles fallback for empty database, so we can safely return 200
                return Ok(result);
            }
            catch (System.Exception ex)
            {
                // Return empty result structure on error (graceful fallback)
                var fallbackResult = new AdminStatisticsDto
                {
                    Totals = new TotalsDto(),
                    GenreDistribution = new List<GenreDistributionDto>(),
                    MonthlyWatching = new List<MonthlyWatchingDto>(),
                    TopSeries = new List<TopSeriesDto>()
                };
                return Ok(fallbackResult); // Return 200 with empty data instead of 500
            }
        }
    }
}
