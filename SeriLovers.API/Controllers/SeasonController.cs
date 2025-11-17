using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System.Collections.Generic;
using System.Linq;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Manages seasons and supports lookup by series.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Season Management")]
    public class SeasonController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;

        public SeasonController(ApplicationDbContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        // GET: api/season
        [HttpGet]
        [SwaggerOperation(Summary = "List seasons", Description = "Retrieves all seasons with their episodes.")]
        public async Task<IActionResult> GetAll()
        {
            var seasons = await _context.Seasons
                .Include(s => s.Episodes)
                .ToListAsync();
            var result = _mapper.Map<IEnumerable<SeasonDto>>(seasons);
            return Ok(result);
        }

        // GET: api/season/{id}
        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Get season", Description = "Fetches a single season including its episodes.")]
        public async Task<IActionResult> GetById(int id)
        {
            var season = await _context.Seasons
                .Include(s => s.Episodes)
                .FirstOrDefaultAsync(s => s.Id == id);

            if (season == null)
            {
                return NotFound(new { message = $"Season with ID {id} not found." });
            }

            var result = _mapper.Map<SeasonDto>(season);
            return Ok(result);
        }

        // GET: api/season/series/{seriesId}
        [HttpGet("series/{seriesId}")]
        [SwaggerOperation(Summary = "Seasons by series", Description = "Lists seasons for a specific series ordered by season number.")]
        public async Task<IActionResult> GetBySeriesId(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var seasons = await _context.Seasons
                .Include(s => s.Episodes)
                .Where(s => s.SeriesId == seriesId)
                .OrderBy(s => s.SeasonNumber)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<SeasonDto>>(seasons);
            return Ok(result);
        }

        // POST: api/season
        [HttpPost]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Create season", Description = "Admin only. Adds a new season to a series.")]
        public async Task<IActionResult> Create([FromBody] SeasonUpsertDto seasonDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            // Validate SeriesId exists
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seasonDto.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {seasonDto.SeriesId} does not exist." });
            }

            // Validate SeasonNumber is unique for the series
            var seasonNumberExists = await _context.Seasons
                .AnyAsync(s => s.SeriesId == seasonDto.SeriesId && s.SeasonNumber == seasonDto.SeasonNumber);
            if (seasonNumberExists)
            {
                return BadRequest(new { message = $"Season {seasonDto.SeasonNumber} already exists for this series." });
            }

            var season = _mapper.Map<Season>(seasonDto);

            _context.Seasons.Add(season);
            await _context.SaveChangesAsync();

            // Load related data for response
            await _context.Entry(season)
                .Collection(s => s.Episodes)
                .LoadAsync();

            var result = _mapper.Map<SeasonDto>(season);
            return CreatedAtAction(nameof(GetById), new { id = season.Id }, result);
        }

        // PUT: api/season/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Update season", Description = "Admin only. Updates season metadata.")]
        public async Task<IActionResult> Update(int id, [FromBody] SeasonUpsertDto seasonDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var existingSeason = await _context.Seasons.FindAsync(id);
            if (existingSeason == null)
            {
                return NotFound(new { message = $"Season with ID {id} not found." });
            }

            // Validate SeriesId exists
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seasonDto.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {seasonDto.SeriesId} does not exist." });
            }

            // Validate SeasonNumber is unique for the series (excluding current season)
            var seasonNumberExists = await _context.Seasons
                .AnyAsync(s => s.SeriesId == seasonDto.SeriesId 
                    && s.SeasonNumber == seasonDto.SeasonNumber 
                    && s.Id != id);
            if (seasonNumberExists)
            {
                return BadRequest(new { message = $"Season {seasonDto.SeasonNumber} already exists for this series." });
            }

            // Update properties
            existingSeason.SeriesId = seasonDto.SeriesId;
            existingSeason.SeasonNumber = seasonDto.SeasonNumber;
            existingSeason.Title = seasonDto.Title;
            existingSeason.Description = seasonDto.Description;
            existingSeason.ReleaseDate = seasonDto.ReleaseDate;

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
                .Collection(s => s.Episodes)
                .LoadAsync();

            var result = _mapper.Map<SeasonDto>(existingSeason);
            return Ok(result);
        }

        // DELETE: api/season/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Delete season", Description = "Admin only. Deletes a season and its episodes.")]
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

