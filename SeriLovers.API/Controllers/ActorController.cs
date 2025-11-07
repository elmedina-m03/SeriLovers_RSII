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
    public class ActorController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public ActorController(ApplicationDbContext context)
        {
            _context = context;
        }

        // GET: api/actor
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var actors = await _context.Actors
                .Include(a => a.Series)
                .OrderBy(a => a.LastName)
                .ThenBy(a => a.FirstName)
                .ToListAsync();
            return Ok(actors);
        }

        // GET: api/actor/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var actor = await _context.Actors
                .Include(a => a.Series)
                .FirstOrDefaultAsync(a => a.Id == id);

            if (actor == null)
            {
                return NotFound(new { message = $"Actor with ID {id} not found." });
            }

            return Ok(actor);
        }

        // GET: api/actor/search?name={name}
        [HttpGet("search")]
        public async Task<IActionResult> Search([FromQuery] string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return BadRequest(new { message = "Search name parameter is required." });
            }

            var actors = await _context.Actors
                .Include(a => a.Series)
                .Where(a => a.FirstName.Contains(name) || a.LastName.Contains(name))
                .OrderBy(a => a.LastName)
                .ThenBy(a => a.FirstName)
                .ToListAsync();

            return Ok(actors);
        }

        // GET: api/actor/series/{seriesId}
        [HttpGet("series/{seriesId}")]
        public async Task<IActionResult> GetBySeriesId(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var actors = await _context.Actors
                .Include(a => a.Series)
                .Where(a => a.Series.Any(s => s.Id == seriesId))
                .OrderBy(a => a.LastName)
                .ThenBy(a => a.FirstName)
                .ToListAsync();

            return Ok(actors);
        }

        // POST: api/actor
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] Actor actor)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            // Validate FirstName is not empty
            if (string.IsNullOrWhiteSpace(actor.FirstName))
            {
                return BadRequest(new { message = "FirstName is required." });
            }

            // Validate LastName is not empty
            if (string.IsNullOrWhiteSpace(actor.LastName))
            {
                return BadRequest(new { message = "LastName is required." });
            }

            // Validate DateOfBirth is not in the future
            if (actor.DateOfBirth.HasValue && actor.DateOfBirth > DateTime.Now)
            {
                return BadRequest(new { message = "DateOfBirth cannot be in the future." });
            }

            _context.Actors.Add(actor);
            await _context.SaveChangesAsync();

            // Load related data for response
            await _context.Entry(actor)
                .Collection(a => a.Series)
                .LoadAsync();

            return CreatedAtAction(nameof(GetById), new { id = actor.Id }, actor);
        }

        // PUT: api/actor/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] Actor actor)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            if (id != actor.Id)
            {
                return BadRequest(new { message = "ID mismatch between URL and request body." });
            }

            var existingActor = await _context.Actors.FindAsync(id);
            if (existingActor == null)
            {
                return NotFound(new { message = $"Actor with ID {id} not found." });
            }

            // Validate FirstName is not empty
            if (string.IsNullOrWhiteSpace(actor.FirstName))
            {
                return BadRequest(new { message = "FirstName is required." });
            }

            // Validate LastName is not empty
            if (string.IsNullOrWhiteSpace(actor.LastName))
            {
                return BadRequest(new { message = "LastName is required." });
            }

            // Validate DateOfBirth is not in the future
            if (actor.DateOfBirth.HasValue && actor.DateOfBirth > DateTime.Now)
            {
                return BadRequest(new { message = "DateOfBirth cannot be in the future." });
            }

            // Update properties
            existingActor.FirstName = actor.FirstName;
            existingActor.LastName = actor.LastName;
            existingActor.DateOfBirth = actor.DateOfBirth;
            existingActor.Biography = actor.Biography;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                if (!await ActorExists(id))
                {
                    return NotFound(new { message = $"Actor with ID {id} not found." });
                }
                throw;
            }

            // Load related data for response
            await _context.Entry(existingActor)
                .Collection(a => a.Series)
                .LoadAsync();

            return Ok(existingActor);
        }

        // DELETE: api/actor/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(int id)
        {
            var actor = await _context.Actors.FindAsync(id);
            if (actor == null)
            {
                return NotFound(new { message = $"Actor with ID {id} not found." });
            }

            _context.Actors.Remove(actor);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        private async Task<bool> ActorExists(int id)
        {
            return await _context.Actors.AnyAsync(e => e.Id == id);
        }
    }
}

