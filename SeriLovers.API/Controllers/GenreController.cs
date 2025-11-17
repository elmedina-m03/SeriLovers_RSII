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
    /// Exposes operations for managing genres and discovering series by genre.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Genre Management")]
    public class GenreController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;

        public GenreController(ApplicationDbContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        // GET: api/genre
        [HttpGet]
        [SwaggerOperation(Summary = "List genres", Description = "Retrieves all genres and linked series.")]
        public async Task<IActionResult> GetAll()
        {
            var genres = await _context.Genres
                .Include(g => g.SeriesGenres)
                    .ThenInclude(sg => sg.Series)
                .OrderBy(g => g.Name)
                .ToListAsync();
            var result = _mapper.Map<IEnumerable<GenreDto>>(genres);
            return Ok(result);
        }

        // GET: api/genre/{id}
        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Get genre", Description = "Fetches a single genre with related series.")]
        public async Task<IActionResult> GetById(int id)
        {
            var genre = await _context.Genres
                .Include(g => g.SeriesGenres)
                    .ThenInclude(sg => sg.Series)
                .FirstOrDefaultAsync(g => g.Id == id);

            if (genre == null)
            {
                return NotFound(new { message = $"Genre with ID {id} not found." });
            }

            var result = _mapper.Map<GenreDto>(genre);
            return Ok(result);
        }

        // GET: api/genre/search?name={name}
        [HttpGet("search")]
        [SwaggerOperation(Summary = "Search genres", Description = "Search for genres by name.")]
        public async Task<IActionResult> Search([FromQuery] string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return BadRequest(new { message = "Search name parameter is required." });
            }

            var genres = await _context.Genres
                .Include(g => g.SeriesGenres)
                    .ThenInclude(sg => sg.Series)
                .Where(g => g.Name.Contains(name))
                .OrderBy(g => g.Name)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<GenreDto>>(genres);
            return Ok(result);
        }

        // GET: api/genre/series/{seriesId}
        [HttpGet("series/{seriesId}")]
        [SwaggerOperation(Summary = "Genres by series", Description = "Lists genres associated with the given series.")]
        public async Task<IActionResult> GetBySeriesId(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var genres = await _context.Genres
                .Include(g => g.SeriesGenres)
                    .ThenInclude(sg => sg.Series)
                .Where(g => g.SeriesGenres.Any(sg => sg.SeriesId == seriesId))
                .OrderBy(g => g.Name)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<GenreDto>>(genres);
            return Ok(result);
        }

        // POST: api/genre
        [HttpPost]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Create genre", Description = "Admin only. Adds a new genre entry.")]
        public async Task<IActionResult> Create([FromBody] GenreUpsertDto genreDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            // Validate Name is not empty
            if (string.IsNullOrWhiteSpace(genreDto.Name))
            {
                return BadRequest(new { message = "Name is required." });
            }

            var trimmedName = genreDto.Name.Trim();

            // Validate Name is unique (case-insensitive)
            var nameExists = await _context.Genres
                .AnyAsync(g => g.Name.ToLower() == trimmedName.ToLower());
            if (nameExists)
            {
                return BadRequest(new { message = $"Genre with name '{trimmedName}' already exists." });
            }

            var genre = _mapper.Map<Genre>(genreDto);
            genre.Name = trimmedName;

            _context.Genres.Add(genre);
            
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException ex)
            {
                // Handle unique constraint violation
                if (ex.InnerException?.Message.Contains("UNIQUE") == true || 
                    ex.InnerException?.Message.Contains("duplicate") == true)
                {
                    return BadRequest(new { message = $"Genre with name '{trimmedName}' already exists." });
                }
                throw;
            }

            // Load related data for response
            await _context.Entry(genre)
                .Collection(g => g.SeriesGenres)
                .Query()
                .Include(sg => sg.Series)
                .LoadAsync();

            var result = _mapper.Map<GenreDto>(genre);

            return CreatedAtAction(nameof(GetById), new { id = genre.Id }, result);
        }

        // PUT: api/genre/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Update genre", Description = "Admin only. Updates the name of an existing genre.")]
        public async Task<IActionResult> Update(int id, [FromBody] GenreUpsertDto genreDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var existingGenre = await _context.Genres
                .Include(g => g.SeriesGenres)
                .FirstOrDefaultAsync(g => g.Id == id);
            if (existingGenre == null)
            {
                return NotFound(new { message = $"Genre with ID {id} not found." });
            }

            // Validate Name is not empty
            if (string.IsNullOrWhiteSpace(genreDto.Name))
            {
                return BadRequest(new { message = "Name is required." });
            }

            var trimmedName = genreDto.Name.Trim();

            // Validate Name is unique (case-insensitive, excluding current genre)
            var nameExists = await _context.Genres
                .AnyAsync(g => g.Name.ToLower() == trimmedName.ToLower() && g.Id != id);
            if (nameExists)
            {
                return BadRequest(new { message = $"Genre with name '{trimmedName}' already exists." });
            }

            // Update properties
            existingGenre.Name = trimmedName;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!await GenreExists(id))
                {
                    return NotFound(new { message = $"Genre with ID {id} not found." });
                }
                throw;
            }
            catch (DbUpdateException ex)
            {
                // Handle unique constraint violation
                if (ex.InnerException?.Message.Contains("UNIQUE") == true || 
                    ex.InnerException?.Message.Contains("duplicate") == true)
                {
                    return BadRequest(new { message = $"Genre with name '{trimmedName}' already exists." });
                }
                throw;
            }

            // Load related data for response
            await _context.Entry(existingGenre)
                .Collection(g => g.SeriesGenres)
                .Query()
                .Include(sg => sg.Series)
                .LoadAsync();

            var result = _mapper.Map<GenreDto>(existingGenre);
            return Ok(result);
        }

        // DELETE: api/genre/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Delete genre", Description = "Admin only. Deletes a genre that is not associated with any series.")]
        public async Task<IActionResult> Delete(int id)
        {
            var genre = await _context.Genres
                .Include(g => g.SeriesGenres)
                .FirstOrDefaultAsync(g => g.Id == id);
            if (genre == null)
            {
                return NotFound(new { message = $"Genre with ID {id} not found." });
            }

            if (genre.SeriesGenres.Any())
            {
                return BadRequest(new { message = $"Cannot delete genre '{genre.Name}' because it is associated with one or more series." });
            }

            _context.Genres.Remove(genre);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private async Task<bool> GenreExists(int id)
        {
            return await _context.Genres.AnyAsync(e => e.Id == id);
        }
    }
}

