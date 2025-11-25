using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using System.Linq;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Provides admin dashboard statistics and analytics.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("Admin Statistics")]
    public class AdminStatsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public AdminStatsController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet("stats")]
        [SwaggerOperation(
            Summary = "Get admin dashboard statistics",
            Description = "Retrieves various counts and genre distribution for the admin dashboard.")]
        public async Task<IActionResult> GetStats()
        {
            var usersCount = await _context.Users.CountAsync();
            var seriesCount = await _context.Series.CountAsync();
            var actorsCount = await _context.Actors.CountAsync();
            var ratingsCount = await _context.Ratings.CountAsync();
            var watchlistCount = await _context.Watchlists.CountAsync();

            var genreDistribution = await _context.SeriesGenres
                .Include(sg => sg.Genre)
                .Where(sg => sg.Genre != null)
                .GroupBy(sg => sg.Genre!.Name)
                .Select(g => new { genre = g.Key, count = g.Count() })
                .OrderByDescending(g => g.count)
                .ToListAsync();

            return Ok(new
            {
                usersCount,
                seriesCount,
                actorsCount,
                ratingsCount,
                watchlistCount,
                genreDistribution
            });
        }
    }
}

