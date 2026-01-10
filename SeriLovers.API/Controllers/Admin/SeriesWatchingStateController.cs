using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;
using SeriLovers.API.Domain.Exceptions;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using SeriLovers.API.Services;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers.Admin
{
    /// <summary>
    /// Admin API for managing and testing series watching states
    /// </summary>
    [ApiController]
    [Route("api/admin/[controller]")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("Admin - Series Watching State Management")]
    public class SeriesWatchingStateController : ControllerBase
    {
        private readonly ISeriesWatchingStateService _watchingStateService;
        private readonly ApplicationDbContext _context;
        private readonly ILogger<SeriesWatchingStateController> _logger;

        public SeriesWatchingStateController(
            ISeriesWatchingStateService watchingStateService,
            ApplicationDbContext context,
            ILogger<SeriesWatchingStateController> logger)
        {
            _watchingStateService = watchingStateService;
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Gets the current watching status for a user and series
        /// </summary>
        /// <param name="userId">The user ID</param>
        /// <param name="seriesId">The series ID</param>
        /// <returns>The current watching status</returns>
        [HttpGet("status")]
        [SwaggerOperation(
            Summary = "Get watching status",
            Description = "Retrieves the current watching status for a user and series")]
        public async Task<IActionResult> GetStatus(
            [FromQuery] int userId,
            [FromQuery] int seriesId)
        {
            try
            {
                var status = await _watchingStateService.GetStatusAsync(userId, seriesId);
                return Ok(new
                {
                    UserId = userId,
                    SeriesId = seriesId,
                    Status = status.ToString(),
                    StatusValue = (int)status
                });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Updates the watching status for a user and series based on watched episodes
        /// </summary>
        /// <param name="userId">The user ID</param>
        /// <param name="seriesId">The series ID</param>
        /// <returns>The updated watching status</returns>
        [HttpPost("update")]
        [SwaggerOperation(
            Summary = "Update watching status",
            Description = "Updates the watching status for a user and series based on watched episodes")]
        public async Task<IActionResult> UpdateStatus(
            [FromQuery] int userId,
            [FromQuery] int seriesId)
        {
            try
            {
                var status = await _watchingStateService.UpdateStatusAsync(userId, seriesId);
                return Ok(new
                {
                    UserId = userId,
                    SeriesId = seriesId,
                    Status = status.ToString(),
                    StatusValue = (int)status,
                    Message = "Status updated successfully"
                });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Validates that a review can be created for the series
        /// </summary>
        /// <param name="userId">The user ID</param>
        /// <param name="seriesId">The series ID</param>
        /// <returns>Validation result</returns>
        [HttpPost("validate-review")]
        [SwaggerOperation(
            Summary = "Validate review creation",
            Description = "Validates that a review can be created (only allowed when series is Finished)")]
        public async Task<IActionResult> ValidateReviewCreation(
            [FromQuery] int userId,
            [FromQuery] int seriesId)
        {
            try
            {
                await _watchingStateService.ValidateReviewCreationAsync(userId, seriesId);
                return Ok(new
                {
                    UserId = userId,
                    SeriesId = seriesId,
                    CanCreateReview = true,
                    Message = "Review creation is allowed"
                });
            }
            catch (ReviewNotAllowedException ex)
            {
                return BadRequest(new
                {
                    UserId = userId,
                    SeriesId = seriesId,
                    CanCreateReview = false,
                    Message = ex.Message,
                    CurrentState = ex.CurrentState.ToString()
                });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }

        /// <summary>
        /// Backfills SeriesWatchingStates for all existing EpisodeProgress records
        /// </summary>
        [HttpPost("backfill")]
        [SwaggerOperation(
            Summary = "Backfill series watching states",
            Description = "Creates SeriesWatchingStates records for all existing EpisodeProgress data. Useful for migrating existing data.")]
        public async Task<IActionResult> BackfillStates()
        {
            try
            {
                // Get all unique user-series combinations from EpisodeProgress
                var userSeriesCombinations = await _context.EpisodeProgresses
                    .Where(ep => ep.IsCompleted)
                    .Include(ep => ep.Episode)
                        .ThenInclude(e => e.Season)
                    .Select(ep => new
                    {
                        UserId = ep.UserId,
                        SeriesId = ep.Episode.Season.SeriesId
                    })
                    .Distinct()
                    .ToListAsync();

                int processed = 0;
                int errors = 0;

                foreach (var combo in userSeriesCombinations)
                {
                    try
                    {
                        await _watchingStateService.UpdateStatusAsync(combo.UserId, combo.SeriesId);
                        processed++;
                    }
                    catch (Exception ex)
                    {
                        errors++;
                        _logger.LogWarning(ex, "Error backfilling for UserId={UserId}, SeriesId={SeriesId}", combo.UserId, combo.SeriesId);
                    }
                }

                return Ok(new
                {
                    Message = "Backfill completed",
                    Processed = processed,
                    Errors = errors,
                    Total = userSeriesCombinations.Count
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = $"Error during backfill: {ex.Message}" });
            }
        }

        /// <summary>
        /// Gets all SeriesWatchingStates from the database (for debugging)
        /// </summary>
        [HttpGet("all")]
        [SwaggerOperation(
            Summary = "Get all series watching states",
            Description = "Retrieves all SeriesWatchingStates records from the database (for debugging purposes)")]
        public async Task<IActionResult> GetAllStates()
        {
            try
            {
                var states = await _context.SeriesWatchingStates
                    .Include(s => s.User)
                    .Include(s => s.Series)
                    .ToListAsync();

                var result = states.Select(s => new
                {
                    Id = s.Id,
                    UserId = s.UserId,
                    UserName = s.User?.UserName ?? "Unknown",
                    SeriesId = s.SeriesId,
                    SeriesTitle = s.Series?.Title ?? "Unknown",
                    Status = s.Status.ToString(),
                    StatusValue = (int)s.Status,
                    WatchedEpisodesCount = s.WatchedEpisodesCount,
                    TotalEpisodesCount = s.TotalEpisodesCount,
                    CreatedAt = s.CreatedAt,
                    LastUpdated = s.LastUpdated
                }).ToList();

                return Ok(new
                {
                    Count = result.Count,
                    States = result
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving all SeriesWatchingStates");
                return StatusCode(500, new { message = $"Error retrieving states: {ex.Message}", stackTrace = ex.StackTrace });
            }
        }

        /// <summary>
        /// Tests the UpdateStatusAsync method directly (for debugging)
        /// </summary>
        [HttpPost("test-update")]
        [SwaggerOperation(
            Summary = "Test update status",
            Description = "Tests the UpdateStatusAsync method directly with provided userId and seriesId (for debugging)")]
        public async Task<IActionResult> TestUpdateStatus(
            [FromQuery] int userId,
            [FromQuery] int seriesId)
        {
            try
            {
                _logger.LogInformation("TestUpdateStatus called: UserId={UserId}, SeriesId={SeriesId}", userId, seriesId);

                var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
                if (!seriesExists)
                {
                    return BadRequest(new { message = $"Series with ID {seriesId} does not exist" });
                }

                var userExists = await _context.Users.AnyAsync(u => u.Id == userId);
                if (!userExists)
                {
                    return BadRequest(new { message = $"User with ID {userId} does not exist" });
                }

                var episodeProgressBefore = await _context.EpisodeProgresses
                    .Where(ep => ep.UserId == userId && ep.IsCompleted)
                    .Include(ep => ep.Episode)
                        .ThenInclude(e => e.Season)
                    .Where(ep => ep.Episode.Season.SeriesId == seriesId)
                    .CountAsync();

                var status = await _watchingStateService.UpdateStatusAsync(userId, seriesId);

                var stateAfter = await _context.SeriesWatchingStates
                    .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);

                return Ok(new
                {
                    Success = true,
                    UserId = userId,
                    SeriesId = seriesId,
                    Status = status.ToString(),
                    StatusValue = (int)status,
                    EpisodeProgressCount = episodeProgressBefore,
                    StateRecord = stateAfter != null ? new
                    {
                        Id = stateAfter.Id,
                        Status = stateAfter.Status.ToString(),
                        WatchedEpisodesCount = stateAfter.WatchedEpisodesCount,
                        TotalEpisodesCount = stateAfter.TotalEpisodesCount,
                        CreatedAt = stateAfter.CreatedAt,
                        LastUpdated = stateAfter.LastUpdated
                    } : null,
                    Message = "UpdateStatusAsync completed successfully"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "TestUpdateStatus FAILED: UserId={UserId}, SeriesId={SeriesId}", userId, seriesId);
                return StatusCode(500, new
                {
                    Success = false,
                    UserId = userId,
                    SeriesId = seriesId,
                    Message = $"Error: {ex.Message}",
                    StackTrace = ex.StackTrace,
                    InnerException = ex.InnerException?.Message
                });
            }
        }

    }
}
