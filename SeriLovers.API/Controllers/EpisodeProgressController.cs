using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;
using SeriLovers.API.Domain.StateMachine;
using SeriLovers.API.Events;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using SeriLovers.API.Services;
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
        private readonly ChallengeService _challengeService;
        private readonly IMessageBusService _messageBusService;
        private readonly ILogger<EpisodeProgressController> _logger;
        private readonly ISeriesWatchingStateService _seriesWatchingStateService;

        public EpisodeProgressController(
            ApplicationDbContext context,
            IMapper mapper,
            ILogger<EpisodeProgressController> logger,
            UserManager<ApplicationUser> userManager,
            ChallengeService challengeService,
            IMessageBusService messageBusService,
            ISeriesWatchingStateService seriesWatchingStateService)
        {
            _context = context;
            _mapper = mapper;
            _logger = logger;
            _userManager = userManager;
            _challengeService = challengeService;
            _messageBusService = messageBusService;
            _seriesWatchingStateService = seriesWatchingStateService;
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

            var episode = await _context.Episodes
                .Include(e => e.Season)
                    .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(e => e.Id == dto.EpisodeId);

            if (episode == null)
            {
                _logger.LogError("Episode not found: EpisodeId={EpisodeId}", dto.EpisodeId);
                return NotFound(new { message = $"Episode with ID {dto.EpisodeId} not found." });
            }

            var seriesId = episode.Season?.SeriesId ?? 0;
            if (seriesId <= 0 && episode.SeasonId > 0)
            {
                var season = await _context.Seasons
                    .AsNoTracking()
                    .FirstOrDefaultAsync(s => s.Id == episode.SeasonId);
                seriesId = season?.SeriesId ?? 0;
            }

            if (seriesId <= 0)
            {
                _logger.LogError("Failed to get SeriesId for EpisodeId={EpisodeId}, SeasonId={SeasonId}", dto.EpisodeId, episode.SeasonId);
            }

            var existingProgress = await _context.EpisodeProgresses
                .FirstOrDefaultAsync(ep => ep.UserId == currentUserId.Value && ep.EpisodeId == dto.EpisodeId);

            EpisodeProgress savedProgress;
            if (existingProgress != null)
            {
                existingProgress.WatchedAt = DateTime.UtcNow;
                existingProgress.IsCompleted = dto.IsCompleted;
                savedProgress = existingProgress;
            }
            else
            {
                var progress = new EpisodeProgress
                {
                    UserId = currentUserId.Value,
                    EpisodeId = dto.EpisodeId,
                    WatchedAt = DateTime.UtcNow,
                    IsCompleted = dto.IsCompleted
                };
                _context.EpisodeProgresses.Add(progress);
                savedProgress = progress;
            }

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to save EpisodeProgress: EpisodeId={EpisodeId}, UserId={UserId}", dto.EpisodeId, currentUserId);
                throw;
            }

            if (dto.IsCompleted && currentUserId.HasValue && seriesId > 0)
            {
                try
                {
                    await _seriesWatchingStateService.UpdateStatusAsync(currentUserId.Value, seriesId);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error updating series watching state for user {UserId} and series {SeriesId}. EpisodeId: {EpisodeId}", 
                        currentUserId.Value, seriesId, dto.EpisodeId);
                }
            }

            // Update challenge progress based on real watched data
            if (currentUserId.HasValue)
            {
                try
                {
                    await _challengeService.UpdateChallengeProgressAsync(currentUserId.Value);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error updating challenge progress for user {UserId}", currentUserId.Value);
                }

                _ = Task.Run(async () =>
                {
                    try
                    {
                        var user = await _userManager.FindByIdAsync(currentUserId.Value.ToString());
                        var episodeWatchedEvent = new EpisodeWatchedEvent
                        {
                            EpisodeId = episode.Id,
                            EpisodeNumber = episode.EpisodeNumber,
                            SeasonId = episode.SeasonId,
                            SeasonNumber = episode.Season?.SeasonNumber ?? 0,
                            SeriesId = episode.Season?.SeriesId ?? 0,
                            SeriesTitle = episode.Season?.Series?.Title ?? "Unknown",
                            UserId = currentUserId.Value,
                            UserName = user?.UserName ?? user?.Email ?? "Unknown",
                            IsCompleted = dto.IsCompleted,
                            WatchedAt = DateTime.UtcNow
                        };
                        await _messageBusService.PublishEventAsync(episodeWatchedEvent);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Error publishing EpisodeWatchedEvent for EpisodeId={EpisodeId}", episode.Id);
                    }
                });
            }

            var updatedProgress = await _context.EpisodeProgresses
                .Include(ep => ep.User)
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(ep => ep.UserId == currentUserId.Value && ep.EpisodeId == dto.EpisodeId);

            if (updatedProgress == null)
            {
                return NotFound(new { message = $"Episode progress not found after saving." });
            }

            if (updatedProgress.Episode == null || updatedProgress.Episode.Season == null || updatedProgress.Episode.Season.Series == null)
            {
                _logger.LogWarning("EpisodeProgress {ProgressId} has null navigation properties. EpisodeId: {EpisodeId}, UserId: {UserId}", 
                    updatedProgress.Id, dto.EpisodeId, currentUserId.Value);
                
                await _context.Entry(updatedProgress).Reference(ep => ep.Episode).LoadAsync();
                if (updatedProgress.Episode != null)
                {
                    await _context.Entry(updatedProgress.Episode).Reference(e => e.Season).LoadAsync();
                    if (updatedProgress.Episode.Season != null)
                    {
                        await _context.Entry(updatedProgress.Episode.Season).Reference(s => s.Series).LoadAsync();
                    }
                }
            }

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

            var totalEpisodes = series.Seasons.Sum(s => s.Episodes.Count);
            var seriesEpisodeIds = series.Seasons
                .SelectMany(s => s.Episodes)
                .Select(e => e.Id)
                .ToList();

            // Get all episode progress records for this series (including non-completed ones for debugging)
            var allProgress = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == currentUserId.Value && 
                            seriesEpisodeIds.Contains(ep.EpisodeId))
                .ToListAsync();
            
            // Log any records with IsCompleted = false for debugging
            var incompleteRecords = allProgress.Where(ep => !ep.IsCompleted).ToList();
            if (incompleteRecords.Any())
            {
                _logger.LogWarning("Found {Count} incomplete episode progress records for UserId={UserId}, SeriesId={SeriesId}. EpisodeIds: {EpisodeIds}",
                    incompleteRecords.Count, currentUserId.Value, seriesId, 
                    string.Join(", ", incompleteRecords.Select(ep => ep.EpisodeId)));
            }
            
            // Only count completed episodes
            var watchedEpisodeIds = allProgress
                .Where(ep => ep.IsCompleted)
                .Select(ep => ep.EpisodeId)
                .Distinct()
                .ToList();
            
            var watchedEpisodes = watchedEpisodeIds.Distinct().Count();

            var lastWatched = await _context.EpisodeProgresses
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                .Where(ep => ep.UserId == currentUserId.Value && 
                            ep.Episode.Season.SeriesId == seriesId &&
                            ep.IsCompleted)
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
        /// Get all series with their watching status for current user
        /// </summary>
        [HttpGet("user/status")]
        [SwaggerOperation(Summary = "Get all series with status", Description = "Gets all series with their watching status (To Do, In Progress, Finished) for the current user. Includes series with episode progress even if not in watchlist.")]
        public async Task<IActionResult> GetUserSeriesWithStatus()
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var seriesWithProgress = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == currentUserId.Value && ep.IsCompleted)
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .Select(ep => ep.Episode.Season.SeriesId)
                .Distinct()
                .ToListAsync();

            var series = await _context.Series
                .Include(s => s.Seasons)
                    .ThenInclude(se => se.Episodes)
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Include(s => s.SeriesActors)
                    .ThenInclude(sa => sa.Actor)
                .Where(s => seriesWithProgress.Contains(s.Id))
                .ToListAsync();

            var watchlistSeriesIds = await _context.Watchlists
                .Where(w => w.UserId == currentUserId.Value)
                .Select(w => w.SeriesId)
                .Distinct()
                .ToListAsync();

            var watchlistSeries = await _context.Series
                .Include(s => s.Seasons)
                    .ThenInclude(se => se.Episodes)
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Include(s => s.SeriesActors)
                    .ThenInclude(sa => sa.Actor)
                .Where(s => watchlistSeriesIds.Contains(s.Id) && !seriesWithProgress.Contains(s.Id))
                .ToListAsync();

            var allSeries = series.Union(watchlistSeries).ToList();
            var result = new List<object>();
            foreach (var s in allSeries)
            {
                var totalEpisodes = s.Seasons.Sum(se => se.Episodes.Count);
                var seriesEpisodeIds = s.Seasons.SelectMany(se => se.Episodes.Select(e => e.Id)).ToList();
                
                var watchedEpisodeIds = await _context.EpisodeProgresses
                    .Where(ep => ep.UserId == currentUserId.Value 
                              && ep.IsCompleted 
                              && seriesEpisodeIds.Contains(ep.EpisodeId))
                    .Select(ep => ep.EpisodeId)
                    .ToListAsync();
                
                var watchedEpisodes = watchedEpisodeIds.Distinct().Count();
                var status = BaseSeriesWatchingState.CalculateState(totalEpisodes, watchedEpisodes);

                result.Add(new
                {
                    series = _mapper.Map<SeriesDto>(s),
                    status = status.ToString(),
                    watchedEpisodes = watchedEpisodes,
                    totalEpisodes = totalEpisodes,
                    progressPercentage = totalEpisodes > 0 ? (watchedEpisodes * 100.0 / totalEpisodes) : 0
                });
            }

            return Ok(result);
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

            var allProgress = await _context.EpisodeProgresses
                .Include(ep => ep.User)
                .Include(ep => ep.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .Where(ep => ep.UserId == currentUserId.Value)
                .OrderByDescending(ep => ep.WatchedAt)
                .ToListAsync();

            var validProgress = allProgress
                .Where(ep => ep.Episode != null 
                    && ep.Episode.Season != null 
                    && ep.Episode.Season.Series != null
                    && ep.IsCompleted)
                .ToList();

            var result = _mapper.Map<IEnumerable<EpisodeProgressDto>>(validProgress);
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

        [HttpGet("season/{seasonId}/current")]
        [SwaggerOperation(Summary = "Get current episode for season", Description = "Gets the highest consecutive episode number where all episodes from 1 to that number are marked as watched. Returns 0 if no episodes are marked or if there's a gap.")]
        public async Task<IActionResult> GetCurrentEpisodeForSeason(int seasonId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var season = await _context.Seasons
                .Include(s => s.Episodes)
                .FirstOrDefaultAsync(s => s.Id == seasonId);

            if (season == null)
            {
                return NotFound(new { message = $"Season with ID {seasonId} not found." });
            }

            var watchedEpisodeIdsList = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == currentUserId.Value && 
                            ep.IsCompleted &&
                            season.Episodes.Select(e => e.Id).Contains(ep.EpisodeId))
                .Select(ep => ep.EpisodeId)
                .ToListAsync();
            
            var watchedEpisodeIds = watchedEpisodeIdsList.ToHashSet();
            var episodes = season.Episodes.OrderBy(e => e.EpisodeNumber).ToList();

            if (episodes.Count == 0)
            {
                return Ok(new { currentEpisode = 0, message = "No episodes in this season" });
            }

            int currentEpisode = 0;
            for (int i = 0; i < episodes.Count; i++)
            {
                var episode = episodes[i];
                if (watchedEpisodeIds.Contains(episode.Id))
                {
                    if (episode.EpisodeNumber == currentEpisode + 1)
                    {
                        currentEpisode = episode.EpisodeNumber;
                    }
                    else
                    {
                        break;
                    }
                }
                else
                {
                    break;
                }
            }

            return Ok(new { 
                currentEpisode = currentEpisode,
                seasonId = seasonId,
                message = currentEpisode > 0 
                    ? $"All episodes up to episode {currentEpisode} are marked" 
                    : "No consecutive episodes marked from episode 1"
            });
        }

        [HttpPost("season/{seasonId}/mark-up-to/{episodeNumber}")]
        [SwaggerOperation(Summary = "Mark episodes up to episode number", Description = "Marks all episodes from 1 to the specified episode number as watched for the current user in the given season.")]
        public async Task<IActionResult> MarkEpisodesUpTo(int seasonId, int episodeNumber)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var season = await _context.Seasons
                .Include(s => s.Episodes)
                .FirstOrDefaultAsync(s => s.Id == seasonId);

            if (season == null)
            {
                return NotFound(new { message = $"Season with ID {seasonId} not found." });
            }

            var allEpisodesInSeason = season.Episodes.OrderBy(e => e.EpisodeNumber).ToList();
            
            if (allEpisodesInSeason.Count == 0)
            {
                return BadRequest(new { 
                    message = $"No episodes found in season {seasonId}.",
                    seasonId = seasonId
                });
            }
            
            var existingEpisodeNumbers = allEpisodesInSeason.Select(e => e.EpisodeNumber).ToList();
            var episodesToMark = allEpisodesInSeason.Take(episodeNumber).ToList();

            if (episodesToMark.Count == 0)
            {
                return BadRequest(new { 
                    message = $"No episodes found in season {seasonId}.",
                    availableEpisodes = existingEpisodeNumbers,
                    requestedCount = episodeNumber
                });
            }

            var existingProgress = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == currentUserId.Value && 
                            episodesToMark.Select(e => e.Id).Contains(ep.EpisodeId))
                .ToListAsync();

            var watchedAt = DateTime.UtcNow;
            int markedCount = 0;
            foreach (var episode in episodesToMark)
            {
                var existing = existingProgress.FirstOrDefault(ep => ep.EpisodeId == episode.Id);
                
                if (existing != null)
                {
                    existing.WatchedAt = watchedAt;
                    existing.IsCompleted = true;
                    markedCount++;
                }
                else
                {
                    var progress = new EpisodeProgress
                    {
                        UserId = currentUserId.Value,
                        EpisodeId = episode.Id,
                        WatchedAt = watchedAt,
                        IsCompleted = true
                    };
                    _context.EpisodeProgresses.Add(progress);
                    markedCount++;
                }
            }

            await _context.SaveChangesAsync();

            var seriesId = season.SeriesId > 0 ? season.SeriesId : 0;
            if (seriesId <= 0)
            {
                var loadedSeason = await _context.Seasons
                    .AsNoTracking()
                    .FirstOrDefaultAsync(s => s.Id == seasonId);
                seriesId = loadedSeason?.SeriesId ?? 0;
            }

            if (currentUserId.HasValue && seriesId > 0)
            {
                try
                {
                    await _seriesWatchingStateService.UpdateStatusAsync(currentUserId.Value, seriesId);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error updating series watching state for user {UserId} and series {SeriesId}. SeasonId: {SeasonId}", 
                        currentUserId.Value, seriesId, seasonId);
                }
            }

            if (currentUserId.HasValue)
            {
                try
                {
                    await _challengeService.UpdateChallengeProgressAsync(currentUserId.Value);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error updating challenge progress for user {UserId}", currentUserId.Value);
                }
            }

            var actualMarkedNumbers = episodesToMark.Select(e => e.EpisodeNumber).OrderBy(n => n).ToList();
            var responseMessage = $"Marked {markedCount} episode(s) as watched: {string.Join(", ", actualMarkedNumbers.Select(n => $"E{n}"))}.";

            return Ok(new { 
                message = responseMessage,
                seasonId = seasonId,
                requestedCount = episodeNumber,
                markedCount = markedCount,
                markedEpisodes = actualMarkedNumbers,
                allEpisodesInSeason = existingEpisodeNumbers
            });
        }

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

