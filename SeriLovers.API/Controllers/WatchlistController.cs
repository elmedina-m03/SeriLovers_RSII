using AutoMapper;
using System;
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
    public class WatchlistController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;

        public WatchlistController(ApplicationDbContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var watchlistEntries = await _context.Watchlists
                .Include(w => w.Series)
                .Include(w => w.User)
                .OrderByDescending(w => w.AddedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<WatchlistDto>>(watchlistEntries);

            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var entry = await _context.Watchlists
                .Include(w => w.Series)
                .Include(w => w.User)
                .FirstOrDefaultAsync(w => w.Id == id);

            if (entry == null)
            {
                return NotFound(new { message = $"Watchlist entry with ID {id} not found." });
            }

            var result = _mapper.Map<WatchlistDto>(entry);

            return Ok(result);
        }

        [HttpGet("user/{userId}")]
        public async Task<IActionResult> GetByUser(int userId)
        {
            var userExists = await _context.Users.AnyAsync(u => u.Id == userId);
            if (!userExists)
            {
                return NotFound(new { message = $"User with ID {userId} not found." });
            }

            var entries = await _context.Watchlists
                .Include(w => w.Series)
                .Where(w => w.UserId == userId)
                .OrderByDescending(w => w.AddedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<WatchlistDto>>(entries);

            return Ok(result);
        }

        [HttpGet("series/{seriesId}")]
        public async Task<IActionResult> GetBySeries(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var entries = await _context.Watchlists
                .Include(w => w.User)
                .Where(w => w.SeriesId == seriesId)
                .OrderByDescending(w => w.AddedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<WatchlistDto>>(entries);

            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] WatchlistCreateDto watchlistDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var userExists = await _context.Users.AnyAsync(u => u.Id == watchlistDto.UserId);
            if (!userExists)
            {
                return BadRequest(new { message = $"User with ID {watchlistDto.UserId} does not exist." });
            }

            var seriesExists = await _context.Series.AnyAsync(s => s.Id == watchlistDto.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {watchlistDto.SeriesId} does not exist." });
            }

            var existingEntry = await _context.Watchlists
                .FirstOrDefaultAsync(w => w.UserId == watchlistDto.UserId && w.SeriesId == watchlistDto.SeriesId);
            if (existingEntry != null)
            {
                return Conflict(new { message = "Series is already in the user's watchlist." });
            }

            var watchlist = _mapper.Map<Watchlist>(watchlistDto);
            watchlist.AddedAt = DateTime.UtcNow;

            _context.Watchlists.Add(watchlist);
            await _context.SaveChangesAsync();

            await _context.Entry(watchlist).Reference(w => w.Series).LoadAsync();
            await _context.Entry(watchlist).Reference(w => w.User).LoadAsync();

            var result = _mapper.Map<WatchlistDto>(watchlist);

            return CreatedAtAction(nameof(GetById), new { id = watchlist.Id }, result);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var entry = await _context.Watchlists.FindAsync(id);
            if (entry == null)
            {
                return NotFound(new { message = $"Watchlist entry with ID {id} not found." });
            }

            _context.Watchlists.Remove(entry);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}

