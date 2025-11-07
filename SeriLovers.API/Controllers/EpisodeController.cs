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
    public class EpisodeController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public EpisodeController(ApplicationDbContext context)
        {
            _context = context;
        }

        // GET: api/episode
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var episodes = await _context.Episodes
                .Include(e => e.Season)
                .ToListAsync();
            return Ok(episodes);
        }

        // GET: api/episode/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var episode = await _context.Episodes
                .Include(e => e.Season)
                .FirstOrDefaultAsync(e => e.Id == id);

            if (episode == null)
            {
                return NotFound(new { message = $"Episode with ID {id} not found." });
            }

            return Ok(episode);
        }

        // GET: api/episode/season/{seasonId}
        [HttpGet("season/{seasonId}")]
        public async Task<IActionResult> GetBySeasonId(int seasonId)
        {
            var seasonExists = await _context.Seasons.AnyAsync(s => s.Id == seasonId);
            if (!seasonExists)
            {
                return NotFound(new { message = $"Season with ID {seasonId} not found." });
            }

            var episodes = await _context.Episodes
                .Include(e => e.Season)
                .Where(e => e.SeasonId == seasonId)
                .OrderBy(e => e.EpisodeNumber)
                .ToListAsync();

            return Ok(episodes);
        }

        // POST: api/episode
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] Episode episode)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            // Validate SeasonId exists
            var seasonExists = await _context.Seasons.AnyAsync(s => s.Id == episode.SeasonId);
            if (!seasonExists)
            {
                return BadRequest(new { message = $"Season with ID {episode.SeasonId} does not exist." });
            }

            // Validate EpisodeNumber is unique for the season
            var episodeNumberExists = await _context.Episodes
                .AnyAsync(e => e.SeasonId == episode.SeasonId && e.EpisodeNumber == episode.EpisodeNumber);
            if (episodeNumberExists)
            {
                return BadRequest(new { message = $"Episode {episode.EpisodeNumber} already exists for this season." });
            }

            // Validate Title is not empty
            if (string.IsNullOrWhiteSpace(episode.Title))
            {
                return BadRequest(new { message = "Title is required." });
            }

            // Validate Rating range if provided
            if (episode.Rating.HasValue && (episode.Rating < 0 || episode.Rating > 10))
            {
                return BadRequest(new { message = "Rating must be between 0 and 10." });
            }

            // Validate DurationMinutes if provided
            if (episode.DurationMinutes.HasValue && episode.DurationMinutes <= 0)
            {
                return BadRequest(new { message = "DurationMinutes must be greater than 0." });
            }

            _context.Episodes.Add(episode);
            await _context.SaveChangesAsync();

            // Load related data for response
            await _context.Entry(episode)
                .Reference(e => e.Season)
                .LoadAsync();

            return CreatedAtAction(nameof(GetById), new { id = episode.Id }, episode);
        }

        // PUT: api/episode/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] Episode episode)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            if (id != episode.Id)
            {
                return BadRequest(new { message = "ID mismatch between URL and request body." });
            }

            var existingEpisode = await _context.Episodes.FindAsync(id);
            if (existingEpisode == null)
            {
                return NotFound(new { message = $"Episode with ID {id} not found." });
            }

            // Validate SeasonId exists
            var seasonExists = await _context.Seasons.AnyAsync(s => s.Id == episode.SeasonId);
            if (!seasonExists)
            {
                return BadRequest(new { message = $"Season with ID {episode.SeasonId} does not exist." });
            }

            // Validate EpisodeNumber is unique for the season (excluding current episode)
            var episodeNumberExists = await _context.Episodes
                .AnyAsync(e => e.SeasonId == episode.SeasonId 
                    && e.EpisodeNumber == episode.EpisodeNumber 
                    && e.Id != id);
            if (episodeNumberExists)
            {
                return BadRequest(new { message = $"Episode {episode.EpisodeNumber} already exists for this season." });
            }

            // Validate Title is not empty
            if (string.IsNullOrWhiteSpace(episode.Title))
            {
                return BadRequest(new { message = "Title is required." });
            }

            // Validate Rating range if provided
            if (episode.Rating.HasValue && (episode.Rating < 0 || episode.Rating > 10))
            {
                return BadRequest(new { message = "Rating must be between 0 and 10." });
            }

            // Validate DurationMinutes if provided
            if (episode.DurationMinutes.HasValue && episode.DurationMinutes <= 0)
            {
                return BadRequest(new { message = "DurationMinutes must be greater than 0." });
            }

            // Update properties
            existingEpisode.SeasonId = episode.SeasonId;
            existingEpisode.EpisodeNumber = episode.EpisodeNumber;
            existingEpisode.Title = episode.Title;
            existingEpisode.Description = episode.Description;
            existingEpisode.AirDate = episode.AirDate;
            existingEpisode.DurationMinutes = episode.DurationMinutes;
            existingEpisode.Rating = episode.Rating;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!await EpisodeExists(id))
                {
                    return NotFound(new { message = $"Episode with ID {id} not found." });
                }
                throw;
            }

            // Load related data for response
            await _context.Entry(existingEpisode)
                .Reference(e => e.Season)
                .LoadAsync();

            return Ok(existingEpisode);
        }

        // DELETE: api/episode/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var episode = await _context.Episodes.FindAsync(id);
            if (episode == null)
            {
                return NotFound(new { message = $"Episode with ID {id} not found." });
            }

            _context.Episodes.Remove(episode);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private async Task<bool> EpisodeExists(int id)
        {
            return await _context.Episodes.AnyAsync(e => e.Id == id);
        }
    }
}

