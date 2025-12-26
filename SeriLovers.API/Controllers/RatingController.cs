using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Events;
using SeriLovers.API.Interfaces;
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

        public RatingController(
            ApplicationDbContext context, 
            IMapper mapper, 
            UserManager<ApplicationUser> userManager,
            IMessageBusService messageBusService)
        {
            _context = context;
            _mapper = mapper;
            _userManager = userManager;
            _messageBusService = messageBusService;
        }

        private async Task<int?> GetCurrentUserIdAsync()
        {
            var user = await _userManager.GetUserAsync(User);
            return user?.Id;
        }

        /// <summary>
        /// Recalculates and updates the average rating for a series based on all user ratings
        /// </summary>
        /// <param name="seriesId">The series ID to update</param>
        private async Task RecalculateSeriesAverageRating(int seriesId)
        {
            var series = await _context.Series
                .Include(s => s.Ratings)
                .FirstOrDefaultAsync(s => s.Id == seriesId);

            if (series == null)
            {
                return;
            }

            if (series.Ratings != null && series.Ratings.Any())
            {
                series.Rating = Math.Round(series.Ratings.Average(r => r.Score), 2);
            }
            else
            {
                series.Rating = 0.0;
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

            // If series has no episodes, consider it "completed" (edge case)
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
            var ratings = await _context.Ratings
                .Include(r => r.Series)
                .Include(r => r.User)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<RatingDto>>(ratings);

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
        [SwaggerOperation(Summary = "Ratings by series", Description = "Lists ratings left for a specific series. Public endpoint - no authentication required.")]
        public async Task<IActionResult> GetBySeries(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var ratings = await _context.Ratings
                .Include(r => r.User)
                .Where(r => r.SeriesId == seriesId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<RatingDto>>(ratings);

            return Ok(result);
        }

        [HttpGet("user/{userId}")]
        [SwaggerOperation(Summary = "Ratings by user", Description = "Lists ratings left by a specific user.")]
        public async Task<IActionResult> GetByUser(int userId)
        {
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
                    // Log but don't fail the request
                    Console.WriteLine($"Error publishing ReviewCreatedEvent: {ex.Message}");
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

