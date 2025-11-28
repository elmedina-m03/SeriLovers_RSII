using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Provides CRUD and lookup operations for actors.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Actor Management")]
    public class ActorController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;

        public ActorController(ApplicationDbContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        // GET: api/actor
        [HttpGet]
        [SwaggerOperation(Summary = "List actors", Description = "Retrieves all actors with optional search and filtering.")]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? search = null,
            [FromQuery] int? age = null,
            [FromQuery] string? sortBy = null,
            [FromQuery] string? sortOrder = "asc")
        {
            var query = _context.Actors
                .AsSplitQuery()
                .Include(a => a.SeriesActors)
                    .ThenInclude(sa => sa.Series)
                .AsQueryable();

            // Search by name
            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchLower = search.ToLower();
                query = query.Where(a => 
                    a.FirstName.ToLower().Contains(searchLower) ||
                    a.LastName.ToLower().Contains(searchLower) ||
                    (a.FirstName + " " + a.LastName).ToLower().Contains(searchLower));
            }

            // Filter by age
            if (age.HasValue)
            {
                var today = DateTime.UtcNow;
                var birthYear = today.Year - age.Value;
                var minDate = new DateTime(birthYear - 1, 12, 31);
                var maxDate = new DateTime(birthYear + 1, 1, 1);
                query = query.Where(a => 
                    a.DateOfBirth.HasValue &&
                    a.DateOfBirth >= minDate &&
                    a.DateOfBirth < maxDate);
            }

            // Apply sorting
            var isAscending = sortOrder?.ToLower() == "asc";
            switch (sortBy?.ToLower())
            {
                case "age":
                    query = isAscending
                        ? query.OrderBy(a => a.DateOfBirth ?? DateTime.MaxValue)
                        : query.OrderByDescending(a => a.DateOfBirth ?? DateTime.MinValue);
                    break;
                case "lastname":
                default:
                    query = isAscending
                        ? query.OrderBy(a => a.LastName).ThenBy(a => a.FirstName)
                        : query.OrderByDescending(a => a.LastName).ThenByDescending(a => a.FirstName);
                    break;
            }

            var actors = await query.ToListAsync();
            var result = _mapper.Map<IEnumerable<ActorDto>>(actors);
            return Ok(result);
        }

        // GET: api/actor/{id}
        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Get actor", Description = "Retrieves a single actor and related series information.")]
        public async Task<IActionResult> GetById(int id)
        {
            var actor = await _context.Actors
                .Include(a => a.SeriesActors)
                    .ThenInclude(sa => sa.Series)
                .FirstOrDefaultAsync(a => a.Id == id);

            if (actor == null)
            {
                return NotFound(new { message = $"Actor with ID {id} not found." });
            }

            var result = _mapper.Map<ActorDto>(actor);
            return Ok(result);
        }

        // GET: api/actor/search?name={name}
        [HttpGet("search")]
        [SwaggerOperation(Summary = "Search actors", Description = "Search for actors by first or last name.")]
        public async Task<IActionResult> Search([FromQuery] string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return BadRequest(new { message = "Search name parameter is required." });
            }

            var actors = await _context.Actors
                .Include(a => a.SeriesActors)
                    .ThenInclude(sa => sa.Series)
                .Where(a => a.FirstName.Contains(name) || a.LastName.Contains(name))
                .OrderBy(a => a.LastName)
                .ThenBy(a => a.FirstName)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<ActorDto>>(actors);
            return Ok(result);
        }

        // GET: api/actor/series/{seriesId}
        [HttpGet("series/{seriesId}")]
        [SwaggerOperation(Summary = "Actors by series", Description = "Lists actors that participated in the specified series.")]
        public async Task<IActionResult> GetBySeriesId(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var actors = await _context.Actors
                .Include(a => a.SeriesActors)
                    .ThenInclude(sa => sa.Series)
                .Where(a => a.SeriesActors.Any(sa => sa.SeriesId == seriesId))
                .OrderBy(a => a.LastName)
                .ThenBy(a => a.FirstName)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<ActorDto>>(actors);
            return Ok(result);
        }

        // POST: api/actor
        [HttpPost]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Create actor", Description = "Admin only. Adds a new actor entry.")]
        public async Task<IActionResult> Create([FromBody] ActorUpsertDto actorDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            // Validate DateOfBirth is not in the future
            if (actorDto.DateOfBirth.HasValue && actorDto.DateOfBirth > DateTime.UtcNow)
            {
                return BadRequest(new { message = "DateOfBirth cannot be in the future." });
            }

            var actor = _mapper.Map<Actor>(actorDto);

            _context.Actors.Add(actor);
            await _context.SaveChangesAsync();

            // Load related data for response
            await _context.Entry(actor)
                .Collection(a => a.SeriesActors)
                .Query()
                .Include(sa => sa.Series)
                .LoadAsync();

            var result = _mapper.Map<ActorDto>(actor);

            return CreatedAtAction(nameof(GetById), new { id = actor.Id }, result);
        }

        // PUT: api/actor/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Update actor", Description = "Admin only. Updates actor biography data.")]
        public async Task<IActionResult> Update(int id, [FromBody] ActorUpsertDto actorDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var existingActor = await _context.Actors
                .Include(a => a.SeriesActors)
                .FirstOrDefaultAsync(a => a.Id == id);
            if (existingActor == null)
            {
                return NotFound(new { message = $"Actor with ID {id} not found." });
            }

            // Validate DateOfBirth is not in the future
            if (actorDto.DateOfBirth.HasValue && actorDto.DateOfBirth > DateTime.UtcNow)
            {
                return BadRequest(new { message = "DateOfBirth cannot be in the future." });
            }

            // Update properties
            existingActor.FirstName = actorDto.FirstName;
            existingActor.LastName = actorDto.LastName;
            existingActor.DateOfBirth = actorDto.DateOfBirth;
            existingActor.Biography = actorDto.Biography;

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
                .Collection(a => a.SeriesActors)
                .Query()
                .Include(sa => sa.Series)
                .LoadAsync();

            var result = _mapper.Map<ActorDto>(existingActor);
            return Ok(result);
        }

        // DELETE: api/actor/{id}
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Delete actor", Description = "Admin only. Deletes an actor if not linked to any series.")]
        public async Task<IActionResult> Delete(int id)
        {
            var actor = await _context.Actors
                .Include(a => a.SeriesActors)
                .FirstOrDefaultAsync(a => a.Id == id);
            if (actor == null)
            {
                return NotFound(new { message = $"Actor with ID {id} not found." });
            }

            if (actor.SeriesActors.Any())
            {
                return BadRequest(new { message = "Cannot delete actor because they are associated with one or more series." });
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

