using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System.Collections.Generic;
using System.Linq;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class EpisodeController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;

        public EpisodeController(ApplicationDbContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        // GET: api/episode
        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var episodes = await _context.Episodes
                .ToListAsync();
            var result = _mapper.Map<IEnumerable<EpisodeDto>>(episodes);
            return Ok(result);
        }

        // GET: api/episode/{id}
        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var episode = await _context.Episodes
                .FirstOrDefaultAsync(e => e.Id == id);

            if (episode == null)
            {
                return NotFound(new { message = $"Episode with ID {id} not found." });
            }

            var result = _mapper.Map<EpisodeDto>(episode);
            return Ok(result);
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
                .Where(e => e.SeasonId == seasonId)
                .OrderBy(e => e.EpisodeNumber)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<EpisodeDto>>(episodes);
            return Ok(result);
        }

        // POST: api/episode
        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] EpisodeUpsertDto episodeDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            // Validate SeasonId exists
            var seasonExists = await _context.Seasons.AnyAsync(s => s.Id == episodeDto.SeasonId);
            if (!seasonExists)
            {
                return BadRequest(new { message = $"Season with ID {episodeDto.SeasonId} does not exist." });
            }

            // Validate EpisodeNumber is unique for the season
            var episodeNumberExists = await _context.Episodes
                .AnyAsync(e => e.SeasonId == episodeDto.SeasonId && e.EpisodeNumber == episodeDto.EpisodeNumber);
            if (episodeNumberExists)
            {
                return BadRequest(new { message = $"Episode {episodeDto.EpisodeNumber} already exists for this season." });
            }

            var episode = _mapper.Map<Episode>(episodeDto);

            _context.Episodes.Add(episode);
            await _context.SaveChangesAsync();

            var result = _mapper.Map<EpisodeDto>(episode);
            return CreatedAtAction(nameof(GetById), new { id = episode.Id }, result);
        }

        // PUT: api/episode/{id}
        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(int id, [FromBody] EpisodeUpsertDto episodeDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var existingEpisode = await _context.Episodes.FindAsync(id);
            if (existingEpisode == null)
            {
                return NotFound(new { message = $"Episode with ID {id} not found." });
            }

            // Validate SeasonId exists
            var seasonExists = await _context.Seasons.AnyAsync(s => s.Id == episodeDto.SeasonId);
            if (!seasonExists)
            {
                return BadRequest(new { message = $"Season with ID {episodeDto.SeasonId} does not exist." });
            }

            // Validate EpisodeNumber is unique for the season (excluding current episode)
            var episodeNumberExists = await _context.Episodes
                .AnyAsync(e => e.SeasonId == episodeDto.SeasonId 
                    && e.EpisodeNumber == episodeDto.EpisodeNumber 
                    && e.Id != id);
            if (episodeNumberExists)
            {
                return BadRequest(new { message = $"Episode {episodeDto.EpisodeNumber} already exists for this season." });
            }

            // Update properties
            existingEpisode.SeasonId = episodeDto.SeasonId;
            existingEpisode.EpisodeNumber = episodeDto.EpisodeNumber;
            existingEpisode.Title = episodeDto.Title;
            existingEpisode.Description = episodeDto.Description;
            existingEpisode.AirDate = episodeDto.AirDate;
            existingEpisode.DurationMinutes = episodeDto.DurationMinutes;
            existingEpisode.Rating = episodeDto.Rating;

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

            var result = _mapper.Map<EpisodeDto>(existingEpisode);
            return Ok(result);
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

