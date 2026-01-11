using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Events;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using SeriLovers.API.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Manages user ratings for series including CRUD operations.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Ratings")]
    public class RatingController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IMessageBusService _messageBusService;
        private readonly ChallengeService _challengeService;
        private readonly ILogger<RatingController> _logger;

        public RatingController(
            ApplicationDbContext context, 
            IMapper mapper, 
            UserManager<ApplicationUser> userManager,
            IMessageBusService messageBusService,
            ChallengeService challengeService,
            ILogger<RatingController> logger)
        {
            _context = context;
            _mapper = mapper;
            _userManager = userManager;
            _messageBusService = messageBusService;
            _challengeService = challengeService;
            _logger = logger;
        }

        private async Task<int?> GetCurrentUserIdAsync()
        {
            var user = await _userManager.GetUserAsync(User);
            return user?.Id;
        }

        /// <summary>
        /// Recalculates and updates the average rating for a series.
        /// Logic:
        /// - If series has NO user ratings: Series.Rating remains the manually entered fallback value (unchanged)
        /// - If series HAS user ratings: Series.Rating = average of user ratings only (manual rating is ignored)
        /// </summary>
        /// <param name="seriesId">The series ID to update</param>
        private async Task RecalculateSeriesAverageRating(int seriesId)
        {
            var series = await _context.Series
                .Include(s => s.Ratings)
                    .ThenInclude(r => r.User)
                .FirstOrDefaultAsync(s => s.Id == seriesId);

            if (series == null)
            {
                return;
            }

            // Filter out test/dummy user ratings - only use real user reviews for calculation
            var realRatings = series.Ratings?
                .Where(r => r.User != null
                    && r.User.Email != null
                    && !r.User.Email.EndsWith("@test.com", StringComparison.OrdinalIgnoreCase)
                    && !r.User.Email.EndsWith("@example.com", StringComparison.OrdinalIgnoreCase)
                    && !r.User.Email.EndsWith("@test", StringComparison.OrdinalIgnoreCase)
                    && !r.User.Email.StartsWith("testuser", StringComparison.OrdinalIgnoreCase))
                .ToList() ?? new List<Rating>();

            if (realRatings.Any())
            {
                // Has user ratings: calculate average ONLY from user ratings (ignore manual rating)
                series.Rating = Math.Round(realRatings.Average(r => r.Score), 2);
            }
            else
            {
                // No user ratings: keep the manually entered fallback value (don't change it)
                // Series.Rating already contains the manually entered value, so we do nothing
                return; // No need to save, rating is already correct
            }

            await _context.SaveChangesAsync();
        }

        /// <summary>
        /// Checks if a user has completed watching all episodes in a series
        /// </summary>
        /// <param name="userId">The user ID to check</param>
        /// <param name="seriesId">The series ID to check</param>
        /// <returns>True if user has completed all episodes, false otherwise</returns>
        private async Task<bool> HasUserCompletedSeries(int userId, int seriesId)
        {
            // Get all episodes in the series (across all seasons)
            var series = await _context.Series
                .Include(s => s.Seasons)
                    .ThenInclude(season => season.Episodes)
                .FirstOrDefaultAsync(s => s.Id == seriesId);

            if (series == null)
            {
                return false;
            }

            // Count total episodes in the series
            var allEpisodeIds = series.Seasons
                .SelectMany(season => season.Episodes)
                .Select(episode => episode.Id)
                .ToList();

            if (allEpisodeIds.Count == 0)
            {
                return true;
            }

            // Count watched (completed) episodes from EpisodeProgress table
            var watchedEpisodeIds = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId 
                          && ep.IsCompleted 
                          && allEpisodeIds.Contains(ep.EpisodeId))
                .Select(ep => ep.EpisodeId)
                .Distinct()
                .ToListAsync();

            // Return true only if watchedEpisodes == totalEpisodes
            return watchedEpisodeIds.Count == allEpisodeIds.Count;
        }

        [HttpGet]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "List all ratings (Admin only)", Description = "Retrieves all ratings with the associated series and user. Admin only.")]
        public async Task<IActionResult> GetAll()
        {
            // Load all ratings with their related entities
            // Don't filter in the query - load everything and filter in memory if needed
            var allRatings = await _context.Ratings
                .AsNoTracking()
                .Include(r => r.Series)
                .Include(r => r.User)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            // Filter out any ratings with missing User or Series (data integrity issues)
            var validRatings = allRatings
                .Where(r => r.User != null && r.Series != null)
                .ToList();

            var result = _mapper.Map<IEnumerable<RatingDto>>(validRatings);

            return Ok(result);
        }

        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Get rating", Description = "Fetches a specific rating by identifier.")]
        public async Task<IActionResult> GetById(int id)
        {
            var rating = await _context.Ratings
                .Include(r => r.Series)
                .Include(r => r.User)
                .FirstOrDefaultAsync(r => r.Id == id);

            if (rating == null)
            {
                return NotFound(new { message = $"Rating with ID {id} not found." });
            }

            var result = _mapper.Map<RatingDto>(rating);

            return Ok(result);
        }

        [HttpGet("series/{seriesId}")]
        [AllowAnonymous]
        [SwaggerOperation(Summary = "Ratings by series", Description = "Lists ratings left for a specific series. Public endpoint - no authentication required. Shows all user ratings.")]
        public async Task<IActionResult> GetBySeries(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var ratingsFromDb = await _context.Ratings
                .Include(r => r.User)
                .Where(r => r.SeriesId == seriesId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            // Show all ratings - don't filter out any users
            // Previously filtered out @test.com, @example.com, @test, and testuser* emails
            // but user wants to see reviews from all users including test users
            var ratings = ratingsFromDb
                .Where(r => r.User != null && r.User.Email != null)
                .ToList();

            var result = _mapper.Map<IEnumerable<RatingDto>>(ratings);

            return Ok(result);
        }

        [HttpGet("user/{userId}")]
        [SwaggerOperation(Summary = "Ratings by user", Description = "Lists ratings left by a specific user. Users can only view their own ratings unless they are an admin.")]
        public async Task<IActionResult> GetByUser(int userId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            // Users can only view their own ratings unless they are an admin
            if (currentUserId.Value != userId && !User.IsInRole("Admin"))
            {
                return Forbid();
            }

            var userExists = await _context.Users.AnyAsync(u => u.Id == userId);
            if (!userExists)
            {
                return NotFound(new { message = $"User with ID {userId} not found." });
            }

            var ratings = await _context.Ratings
                .Include(r => r.Series)
                .Where(r => r.UserId == userId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<RatingDto>>(ratings);

            return Ok(result);
        }

        [HttpPost]
        [SwaggerOperation(Summary = "Rate series", Description = "Adds or updates a rating for the current user based on score. User must have completed all episodes in the series.")]
        public async Task<IActionResult> Create([FromBody] RatingCreateDto ratingDto)
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

            // Check if series exists
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == ratingDto.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {ratingDto.SeriesId} does not exist." });
            }

            // Validate that user has completed the entire series before allowing rating
            var hasCompleted = await HasUserCompletedSeries(currentUserId.Value, ratingDto.SeriesId);
            if (!hasCompleted)
            {
                return BadRequest(new { message = "You must finish the series before leaving a review or rating." });
            }

            var existingRating = await _context.Ratings
                .FirstOrDefaultAsync(r => r.UserId == currentUserId.Value && r.SeriesId == ratingDto.SeriesId);
            if (existingRating != null)
            {
                existingRating.Score = ratingDto.Score;
                existingRating.Comment = ratingDto.Comment;
                existingRating.CreatedAt = DateTime.UtcNow;

                await _context.SaveChangesAsync();

                // Recalculate series average rating
                await RecalculateSeriesAverageRating(ratingDto.SeriesId);

                // Update challenge progress (rating a series counts towards challenges)
                try
                {
                    await _challengeService.UpdateChallengeProgressAsync(currentUserId.Value);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error updating challenge progress for user {UserId}", currentUserId.Value);
                }

                await _context.Entry(existingRating).Reference(r => r.Series).LoadAsync();
                await _context.Entry(existingRating).Reference(r => r.User).LoadAsync();

                var updatedResult = _mapper.Map<RatingDto>(existingRating);
                return Ok(new { message = "rating updated", rating = updatedResult });
            }

            var rating = _mapper.Map<Rating>(ratingDto);
            rating.CreatedAt = DateTime.UtcNow;
            rating.UserId = currentUserId.Value;

            _context.Ratings.Add(rating);
            await _context.SaveChangesAsync();

            // Recalculate series average rating
            await RecalculateSeriesAverageRating(ratingDto.SeriesId);

            // Update challenge progress (rating a series counts towards challenges)
            try
            {
                await _challengeService.UpdateChallengeProgressAsync(currentUserId.Value);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error updating challenge progress after rating creation");
            }

            await _context.Entry(rating).Reference(r => r.Series).LoadAsync();
            await _context.Entry(rating).Reference(r => r.User).LoadAsync();

            // Publish ReviewCreatedEvent (decoupled from main request flow)
            _ = Task.Run(async () =>
            {
                try
                {
                    var reviewEvent = new ReviewCreatedEvent
                    {
                        RatingId = rating.Id,
                        UserId = rating.UserId,
                        UserName = rating.User?.UserName ?? rating.User?.Email ?? "Unknown",
                        SeriesId = rating.SeriesId,
                        SeriesTitle = rating.Series?.Title ?? "Unknown",
                        Score = rating.Score,
                        Comment = rating.Comment,
                        CreatedAt = rating.CreatedAt
                    };
                    await _messageBusService.PublishEventAsync(reviewEvent);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Error publishing ReviewCreatedEvent for RatingId={RatingId}", rating.Id);
                }
            });

            var result = _mapper.Map<RatingDto>(rating);

            return CreatedAtAction(nameof(GetById), new { id = rating.Id }, new { message = "rating added", rating = result });
        }

        [HttpPut("{id}")]
        [SwaggerOperation(Summary = "Update rating", Description = "Updates an existing rating owned by the current user. User must have completed all episodes in the series.")]
        public async Task<IActionResult> Update(int id, [FromBody] RatingUpdateDto ratingDto)
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

            var existingRating = await _context.Ratings
                .Include(r => r.Series)
                .FirstOrDefaultAsync(r => r.Id == id);
            
            if (existingRating == null)
            {
                return NotFound(new { message = $"Rating with ID {id} not found." });
            }

            if (existingRating.UserId != currentUserId.Value && !User.IsInRole("Admin"))
            {
                return Forbid();
            }

            // Validate that user has completed the entire series before allowing rating update
            var hasCompleted = await HasUserCompletedSeries(currentUserId.Value, existingRating.SeriesId);
            if (!hasCompleted)
            {
                return BadRequest(new { message = "You must finish the series before leaving a review or rating." });
            }

            existingRating.Score = ratingDto.Score;
            existingRating.Comment = ratingDto.Comment;

            await _context.SaveChangesAsync();

            // Recalculate series average rating
            await RecalculateSeriesAverageRating(existingRating.SeriesId);

            // Update challenge progress (rating a series counts towards challenges)
            try
            {
                await _challengeService.UpdateChallengeProgressAsync(currentUserId.Value);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error updating challenge progress after rating creation");
            }

            await _context.Entry(existingRating).Reference(r => r.Series).LoadAsync();
            await _context.Entry(existingRating).Reference(r => r.User).LoadAsync();

            var result = _mapper.Map<RatingDto>(existingRating);

            return Ok(new { message = "rating updated", rating = result });
        }

        [HttpDelete("{id}")]
        [SwaggerOperation(Summary = "Delete rating", Description = "Deletes a rating owned by the current user.")]
        public async Task<IActionResult> Delete(int id)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var rating = await _context.Ratings.FindAsync(id);
            if (rating == null)
            {
                return NotFound(new { message = $"Rating with ID {id} not found." });
            }

            if (rating.UserId != currentUserId.Value && !User.IsInRole("Admin"))
            {
                return Forbid();
            }

            var seriesId = rating.SeriesId;
            _context.Ratings.Remove(rating);
            await _context.SaveChangesAsync();

            // Recalculate series average rating after deletion
            await RecalculateSeriesAverageRating(seriesId);

            return Ok(new { message = "rating removed" });
        }
    }
}

