using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using Swashbuckle.AspNetCore.Annotations;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Episode Progress Tracking")]
    public class EpisodeProgressController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;

        public EpisodeProgressController(
            ApplicationDbContext context,
            IMapper mapper,
            UserManager<ApplicationUser> userManager)
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

        /// <summary>
        /// Get the next episode to watch for a series
        /// </summary>
        [HttpGet("series/{seriesId}/next")]
        [SwaggerOperation(Summary = "Get next episode", Description = "Gets the next unwatched episode for a series.")]
        public async Task<IActionResult> GetNextEpisode(int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var series = await _context.Series
                .Include(s => s.Seasons)
                    .ThenInclude(se => se.Episodes)
                .FirstOrDefaultAsync(s => s.Id == seriesId);

            if (series == null)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            // Get all watched episode IDs for this series
            var watchedEpisodeIds = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == currentUserId.Value && ep.IsCompleted)
                .Select(ep => ep.EpisodeId)
                .ToListAsync();

            // Find the first unwatched episode (ordered by season, then episode number)
            var nextEpisode = series.Seasons
                .OrderBy(s => s.SeasonNumber)
                .SelectMany(s => s.Episodes.OrderBy(e => e.EpisodeNumber))
                .FirstOrDefault(e => !watchedEpisodeIds.Contains(e.Id));

            if (nextEpisode == null)
            {
                return Ok(new { message = "All episodes watched", episodeId = (int?)null });
            }

            return Ok(new { episodeId = nextEpisode.Id, episodeNumber = nextEpisode.EpisodeNumber, seasonNumber = nextEpisode.Season.SeasonNumber });
        }

        /// <summary>
        /// Mark an episode as watched
        /// </summary>
        [HttpPost]
        [SwaggerOperation(Summary = "Mark episode as watched", Description = "Marks an episode as watched for the current user.")]
        public async Task<IActionResult> MarkEpisodeWatched([FromBody] EpisodeProgressCreateDto dto)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            // Check if episode exists
            var episode = await _context.Episodes
                .Include(e => e.Season)
                    .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(e => e.Id == dto.EpisodeId);

            if (episode == null)
            {
                return NotFound(new { message = $"Episode with ID {dto.EpisodeId} not found." });
            }

            // Check if progress already exists
            var existingProgress = await _context.EpisodeProgresses
                .FirstOrDefaultAsync(ep => ep.UserId == currentUserId.Value && ep.EpisodeId == dto.EpisodeId);

            if (existingProgress != null)
            {
                // Update existing progress
                existingProgress.WatchedAt = DateTime.UtcNow;
                existingProgress.IsCompleted = dto.IsCompleted;
            }
            else
            {
                // Create new progress
                var progress = new EpisodeProgress
                {
                    UserId = currentUserId.Value,
                    EpisodeId = dto.EpisodeId,
                    WatchedAt = DateTime.UtcNow,
                    IsCompleted = dto.IsCompleted
                };
                _context.EpisodeProgresses.Add(progress);
            }

            await _context.SaveChangesAsync();

            // Return updated progress
            var updatedProgress = await _context.EpisodeProgresses
                .Include(ep => ep.User)
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(ep => ep.UserId == currentUserId.Value && ep.EpisodeId == dto.EpisodeId);

            var result = _mapper.Map<EpisodeProgressDto>(updatedProgress);
            return Ok(result);
        }

        /// <summary>
        /// Get progress for a specific series
        /// </summary>
        [HttpGet("series/{seriesId}")]
        [SwaggerOperation(Summary = "Get series progress", Description = "Gets the watching progress for a specific series.")]
        public async Task<IActionResult> GetSeriesProgress(int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var series = await _context.Series
                .Include(s => s.Seasons)
                    .ThenInclude(se => se.Episodes)
                .FirstOrDefaultAsync(s => s.Id == seriesId);

            if (series == null)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            // Get all watched episodes for this series
            var watchedEpisodeIds = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == currentUserId.Value && ep.IsCompleted)
                .Select(ep => ep.EpisodeId)
                .ToListAsync();

            var totalEpisodes = series.Seasons.Sum(s => s.Episodes.Count);
            var watchedEpisodes = series.Seasons
                .SelectMany(s => s.Episodes)
                .Count(e => watchedEpisodeIds.Contains(e.Id));

            // Find current episode (last watched)
            var lastWatched = await _context.EpisodeProgresses
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                .Where(ep => ep.UserId == currentUserId.Value && 
                            ep.Episode.Season.SeriesId == seriesId)
                .OrderByDescending(ep => ep.WatchedAt)
                .FirstOrDefaultAsync();

            var progress = new SeriesProgressDto
            {
                SeriesId = seriesId,
                SeriesTitle = series.Title,
                TotalEpisodes = totalEpisodes,
                WatchedEpisodes = watchedEpisodes,
                CurrentEpisodeNumber = lastWatched?.Episode.EpisodeNumber ?? 0,
                CurrentSeasonNumber = lastWatched?.Episode.Season.SeasonNumber ?? 0,
                ProgressPercentage = totalEpisodes > 0 ? (watchedEpisodes * 100.0 / totalEpisodes) : 0
            };

            return Ok(progress);
        }

        /// <summary>
        /// Get all watched episodes for current user
        /// </summary>
        [HttpGet]
        [SwaggerOperation(Summary = "Get user progress", Description = "Gets all episode progress for the current user.")]
        public async Task<IActionResult> GetUserProgress()
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var progress = await _context.EpisodeProgresses
                .Include(ep => ep.User)
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .Where(ep => ep.UserId == currentUserId.Value)
                .OrderByDescending(ep => ep.WatchedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<EpisodeProgressDto>>(progress);
            return Ok(result);
        }

        /// <summary>
        /// Get the last watched episode for a series
        /// </summary>
        [HttpGet("series/{seriesId}/last")]
        [SwaggerOperation(Summary = "Get last watched episode", Description = "Gets the last watched episode for a series.")]
        public async Task<IActionResult> GetLastWatchedEpisode(int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var lastWatched = await _context.EpisodeProgresses
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                .Where(ep => ep.UserId == currentUserId.Value && 
                            ep.Episode.Season.SeriesId == seriesId &&
                            ep.IsCompleted)
                .OrderByDescending(ep => ep.WatchedAt)
                .FirstOrDefaultAsync();

            if (lastWatched == null)
            {
                return Ok(new { episodeId = (int?)null, message = "No episodes watched yet" });
            }

            return Ok(new { 
                episodeId = lastWatched.EpisodeId, 
                episodeNumber = lastWatched.Episode.EpisodeNumber,
                seasonNumber = lastWatched.Episode.Season.SeasonNumber
            });
        }

        /// <summary>
        /// Remove episode progress (mark as unwatched)
        /// </summary>
        [HttpDelete("{episodeId}")]
        [SwaggerOperation(Summary = "Remove episode progress", Description = "Removes episode progress (marks as unwatched).")]
        public async Task<IActionResult> RemoveProgress(int episodeId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var progress = await _context.EpisodeProgresses
                .FirstOrDefaultAsync(ep => ep.UserId == currentUserId.Value && ep.EpisodeId == episodeId);

            if (progress == null)
            {
                return NotFound(new { message = "Episode progress not found." });
            }

            _context.EpisodeProgresses.Remove(progress);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Episode progress removed." });
        }
    }
}

