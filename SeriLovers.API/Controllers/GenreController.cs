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
    public class GenreController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public GenreController(ApplicationDbContext context)
        {
            _context = context;
        }

        // GET: api/genre
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var genres = await _context.Genres
                .Include(g => g.Series)
                .OrderBy(g => g.Name)
                .ToListAsync();
            return Ok(genres);
        }

        // GET: api/genre/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var genre = await _context.Genres
                .Include(g => g.Series)
                .FirstOrDefaultAsync(g => g.Id == id);

            if (genre == null)
            {
                return NotFound(new { message = $"Genre with ID {id} not found." });
            }

            return Ok(genre);
        }

        // GET: api/genre/search?name={name}
        [HttpGet("search")]
        public async Task<IActionResult> Search([FromQuery] string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return BadRequest(new { message = "Search name parameter is required." });
            }

            var genres = await _context.Genres
                .Include(g => g.Series)
                .Where(g => g.Name.Contains(name))
                .OrderBy(g => g.Name)
                .ToListAsync();

            return Ok(genres);
        }

        // GET: api/genre/series/{seriesId}
        [HttpGet("series/{seriesId}")]
        public async Task<IActionResult> GetBySeriesId(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var genres = await _context.Genres
                .Include(g => g.Series)
                .Where(g => g.Series.Any(s => s.Id == seriesId))
                .OrderBy(g => g.Name)
                .ToListAsync();

            return Ok(genres);
        }

        // POST: api/genre
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] Genre genre)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            // Validate Name is not empty
            if (string.IsNullOrWhiteSpace(genre.Name))
            {
                return BadRequest(new { message = "Name is required." });
            }

            // Validate Name is unique (case-insensitive)
            var nameExists = await _context.Genres
                .AnyAsync(g => g.Name.ToLower() == genre.Name.Trim().ToLower());
            if (nameExists)
            {
                return BadRequest(new { message = $"Genre with name '{genre.Name}' already exists." });
            }

            // Trim and set the name
            genre.Name = genre.Name.Trim();

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
                    return BadRequest(new { message = $"Genre with name '{genre.Name}' already exists." });
                }
                throw;
            }

            // Load related data for response
            await _context.Entry(genre)
                .Collection(g => g.Series)
                .LoadAsync();

            return CreatedAtAction(nameof(GetById), new { id = genre.Id }, genre);
        }

        // PUT: api/genre/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] Genre genre)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            if (id != genre.Id)
            {
                return BadRequest(new { message = "ID mismatch between URL and request body." });
            }

            var existingGenre = await _context.Genres.FindAsync(id);
            if (existingGenre == null)
            {
                return NotFound(new { message = $"Genre with ID {id} not found." });
            }

            // Validate Name is not empty
            if (string.IsNullOrWhiteSpace(genre.Name))
            {
                return BadRequest(new { message = "Name is required." });
            }

            // Validate Name is unique (case-insensitive, excluding current genre)
            var nameExists = await _context.Genres
                .AnyAsync(g => g.Name.ToLower() == genre.Name.Trim().ToLower() && g.Id != id);
            if (nameExists)
            {
                return BadRequest(new { message = $"Genre with name '{genre.Name}' already exists." });
            }

            // Update properties
            existingGenre.Name = genre.Name.Trim();

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
                    return BadRequest(new { message = $"Genre with name '{genre.Name}' already exists." });
                }
                throw;
            }

            // Load related data for response
            await _context.Entry(existingGenre)
                .Collection(g => g.Series)
                .LoadAsync();

            return Ok(existingGenre);
        }

        // DELETE: api/genre/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var genre = await _context.Genres.FindAsync(id);
            if (genre == null)
            {
                return NotFound(new { message = $"Genre with ID {id} not found." });
            }

            _context.Genres.Remove(genre);
            
            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                // Check if genre is being used by any series
                var hasSeries = await _context.Genres
                    .Include(g => g.Series)
                    .Where(g => g.Id == id)
                    .AnyAsync(g => g.Series.Any());

                if (hasSeries)
                {
                    return BadRequest(new { message = $"Cannot delete genre '{genre.Name}' because it is associated with one or more series." });
                }
                throw;
            }

            return NoContent();
        }

        private async Task<bool> GenreExists(int id)
        {
            return await _context.Genres.AnyAsync(e => e.Id == id);
        }
    }
}

