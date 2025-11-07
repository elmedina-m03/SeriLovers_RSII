using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class SeasonController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public SeasonController(ApplicationDbContext context)
        {
            _context = context;
        }

        // GET: api/season
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var seasons = await _context.Seasons
                .Include(s => s.Series)
                .Include(s => s.Episodes)
                .ToListAsync();
            return Ok(seasons);
        }

        // GET: api/season/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var season = await _context.Seasons
                .Include(s => s.Series)
                .Include(s => s.Episodes)
                .FirstOrDefaultAsync(s => s.Id == id);

            if (season == null)
            {
                return NotFound(new { message = $"Season with ID {id} not found." });
            }

            return Ok(season);
        }

        // GET: api/season/series/{seriesId}
        [HttpGet("series/{seriesId}")]
        public async Task<IActionResult> GetBySeriesId(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var seasons = await _context.Seasons
                .Include(s => s.Series)
                .Include(s => s.Episodes)
                .Where(s => s.SeriesId == seriesId)
                .OrderBy(s => s.SeasonNumber)
                .ToListAsync();

            return Ok(seasons);
        }

        // POST: api/season
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] Season season)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            // Validate SeriesId exists
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == season.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {season.SeriesId} does not exist." });
            }

            // Validate SeasonNumber is unique for the series
            var seasonNumberExists = await _context.Seasons
                .AnyAsync(s => s.SeriesId == season.SeriesId && s.SeasonNumber == season.SeasonNumber);
            if (seasonNumberExists)
            {
                return BadRequest(new { message = $"Season {season.SeasonNumber} already exists for this series." });
            }

            // Validate Title is not empty
            if (string.IsNullOrWhiteSpace(season.Title))
            {
                return BadRequest(new { message = "Title is required." });
            }

            _context.Seasons.Add(season);
            await _context.SaveChangesAsync();

            // Load related data for response
            await _context.Entry(season)
                .Reference(s => s.Series)
                .LoadAsync();
            await _context.Entry(season)
                .Collection(s => s.Episodes)
                .LoadAsync();

            return CreatedAtAction(nameof(GetById), new { id = season.Id }, season);
        }

        // PUT: api/season/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] Season season)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            if (id != season.Id)
            {
                return BadRequest(new { message = "ID mismatch between URL and request body." });
            }

            var existingSeason = await _context.Seasons.FindAsync(id);
            if (existingSeason == null)
            {
                return NotFound(new { message = $"Season with ID {id} not found." });
            }

            // Validate SeriesId exists
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == season.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {season.SeriesId} does not exist." });
            }

            // Validate SeasonNumber is unique for the series (excluding current season)
            var seasonNumberExists = await _context.Seasons
                .AnyAsync(s => s.SeriesId == season.SeriesId 
                    && s.SeasonNumber == season.SeasonNumber 
                    && s.Id != id);
            if (seasonNumberExists)
            {
                return BadRequest(new { message = $"Season {season.SeasonNumber} already exists for this series." });
            }

            // Validate Title is not empty
            if (string.IsNullOrWhiteSpace(season.Title))
            {
                return BadRequest(new { message = "Title is required." });
            }

            // Update properties
            existingSeason.SeriesId = season.SeriesId;
            existingSeason.SeasonNumber = season.SeasonNumber;
            existingSeason.Title = season.Title;
            existingSeason.Description = season.Description;
            existingSeason.ReleaseDate = season.ReleaseDate;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!await SeasonExists(id))
                {
                    return NotFound(new { message = $"Season with ID {id} not found." });
                }
                throw;
            }

            // Load related data for response
            await _context.Entry(existingSeason)
                .Reference(s => s.Series)
                .LoadAsync();
            await _context.Entry(existingSeason)
                .Collection(s => s.Episodes)
                .LoadAsync();

            return Ok(existingSeason);
        }

        // DELETE: api/season/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var season = await _context.Seasons.FindAsync(id);
            if (season == null)
            {
                return NotFound(new { message = $"Season with ID {id} not found." });
            }

            _context.Seasons.Remove(season);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private async Task<bool> SeasonExists(int id)
        {
            return await _context.Seasons.AnyAsync(e => e.Id == id);
        }
    }
}

