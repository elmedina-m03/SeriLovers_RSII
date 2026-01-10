using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using Swashbuckle.AspNetCore.Annotations;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("Seed Data (Admin Only - Development Only)")]
    public class SeedDataController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IWebHostEnvironment _environment;

        public SeedDataController(ApplicationDbContext context, IWebHostEnvironment environment)
        {
            _context = context;
            _environment = environment;
        }

        /// <summary>
        /// Checks if the controller is available (only in Development)
        /// </summary>
        private IActionResult? CheckDevelopmentOnly()
        {
            if (!_environment.IsDevelopment())
            {
                return NotFound(new { message = "This endpoint is only available in Development environment." });
            }
            return null;
        }

        /// <summary>
        /// Seed test episodes for series that don't have any (Development only)
        /// </summary>
        [HttpPost("episodes")]
        [SwaggerOperation(Summary = "Seed episodes", Description = "Creates test episodes (20 per season) for series that don't have any. Admin only. Development only.")]
        public async Task<IActionResult> SeedEpisodes()
        {
            var devCheck = CheckDevelopmentOnly();
            if (devCheck != null) return devCheck;

            // Get all series that don't have seasons/episodes yet
            var seriesWithoutEpisodes = await _context.Series
                .Where(s => !s.Seasons.Any())
                .Take(10) // Limit to first 10 series
                .ToListAsync();

            int episodesCreated = 0;

            foreach (var series in seriesWithoutEpisodes)
            {
                // Create Season 1 with 20 episodes
                var season = new Season
                {
                    SeriesId = series.Id,
                    SeasonNumber = 1,
                    Title = $"{series.Title} - Season 1",
                    Description = $"The first season of {series.Title}",
                    ReleaseDate = series.ReleaseDate,
                };

                _context.Seasons.Add(season);
                await _context.SaveChangesAsync();

                // Create 20 episodes for this season
                for (int i = 1; i <= 20; i++)
                {
                    var episode = new Episode
                    {
                        SeasonId = season.Id,
                        EpisodeNumber = i,
                        Title = $"Episode {i}",
                        Description = $"Episode {i} of {series.Title}",
                        AirDate = series.ReleaseDate.AddDays(i * 7), // Weekly episodes
                        DurationMinutes = 45,
                    };

                    _context.Episodes.Add(episode);
                    episodesCreated++;
                }
            }

            await _context.SaveChangesAsync();

            return Ok(new { 
                message = $"Created {episodesCreated} episodes for {seriesWithoutEpisodes.Count} series",
                seriesCount = seriesWithoutEpisodes.Count,
                episodesCreated = episodesCreated
            });
        }
    }
}

