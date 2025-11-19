using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Provides endpoints for managing personal watchlists.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Watchlists")]
    public class WatchlistController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;

        public WatchlistController(ApplicationDbContext context, IMapper mapper, UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _mapper = mapper;
            _userManager = userManager;
        }

        private async Task<int?> GetCurrentUserIdAsync()
        {
            var user = await _userManager.GetUserAsync(User);
            return user?.Id;
        }

        [HttpGet]
        [SwaggerOperation(Summary = "List watchlist entries", Description = "Retrieves all watchlist entries with associated users and series.")]
        public async Task<IActionResult> GetAll()
        {
            var watchlistEntries = await _context.Watchlists
                .Include(w => w.Series)
                    .ThenInclude(s => s.SeriesGenres)
                        .ThenInclude(sg => sg.Genre)
                .Include(w => w.Series)
                    .ThenInclude(s => s.SeriesActors)
                        .ThenInclude(sa => sa.Actor)
                .Include(w => w.User)
                .OrderByDescending(w => w.AddedAt)
                .ToListAsync();

            // Get unique series IDs
            var seriesIds = watchlistEntries
                .Where(w => w.Series != null)
                .Select(w => w.Series!.Id)
                .Distinct()
                .ToList();

            // Efficiently populate feedback counts for all series at once
            if (seriesIds.Any())
            {
                var ratingCounts = await _context.Ratings
                    .Where(r => seriesIds.Contains(r.SeriesId))
                    .GroupBy(r => r.SeriesId)
                    .Select(g => new { SeriesId = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.SeriesId, x => x.Count);

                var watchlistCounts = await _context.Watchlists
                    .Where(w => seriesIds.Contains(w.SeriesId))
                    .GroupBy(w => w.SeriesId)
                    .Select(g => new { SeriesId = g.Key, Count = g.Count() })
                    .ToDictionaryAsync(x => x.SeriesId, x => x.Count);

                // Set counts on each series
                foreach (var entry in watchlistEntries)
                {
                    if (entry.Series != null)
                    {
                        entry.Series.RatingsCount = ratingCounts.TryGetValue(entry.Series.Id, out var ratingCount) ? ratingCount : 0;
                        entry.Series.WatchlistsCount = watchlistCounts.TryGetValue(entry.Series.Id, out var watchlistCount) ? watchlistCount : 0;
                    }
                }
            }

            var result = _mapper.Map<IEnumerable<WatchlistDto>>(watchlistEntries);

            return Ok(result);
        }

        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Get watchlist entry", Description = "Fetches a single watchlist entry by identifier.")]
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
        [SwaggerOperation(Summary = "Watchlist by user", Description = "Retrieves watchlist items for the specified user.")]
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
        [SwaggerOperation(Summary = "Watchlist by series", Description = "Retrieves watchlist entries containing the specified series.")]
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
        [SwaggerOperation(Summary = "Add to watchlist", Description = "Adds the specified series to the current user's watchlist.")]
        public async Task<IActionResult> Create([FromBody] WatchlistCreateDto watchlistDto)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var seriesExists = await _context.Series.AnyAsync(s => s.Id == watchlistDto.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {watchlistDto.SeriesId} does not exist." });
            }

            var existingEntry = await _context.Watchlists
                .FirstOrDefaultAsync(w => w.UserId == currentUserId.Value && w.SeriesId == watchlistDto.SeriesId);
            if (existingEntry != null)
            {
                await _context.Entry(existingEntry).Reference(w => w.Series).LoadAsync();
                var existingResult = _mapper.Map<WatchlistDto>(existingEntry);
                return Ok(new { message = "series already in watchlist", watchlist = existingResult });
            }

            var watchlist = _mapper.Map<Watchlist>(watchlistDto);
            watchlist.AddedAt = DateTime.UtcNow;
            watchlist.UserId = currentUserId.Value;

            _context.Watchlists.Add(watchlist);
            await _context.SaveChangesAsync();

            await _context.Entry(watchlist).Reference(w => w.Series).LoadAsync();
            await _context.Entry(watchlist).Reference(w => w.User).LoadAsync();

            var result = _mapper.Map<WatchlistDto>(watchlist);

            return CreatedAtAction(nameof(GetById), new { id = watchlist.Id }, new { message = "added to watchlist", watchlist = result });
        }

        [HttpDelete("{seriesId}")]
        [SwaggerOperation(Summary = "Remove from watchlist", Description = "Removes the specified series from the current user's watchlist.")]
        public async Task<IActionResult> Delete(int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var entry = await _context.Watchlists
                .FirstOrDefaultAsync(w => w.UserId == currentUserId.Value && w.SeriesId == seriesId);
            if (entry == null)
            {
                return NotFound(new { message = "Series not found in your watchlist." });
            }

            _context.Watchlists.Remove(entry);
            await _context.SaveChangesAsync();

            return Ok(new { message = "removed from watchlist" });
        }
    }
}

