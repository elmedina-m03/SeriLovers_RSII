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
    [SwaggerTag("Episode Reviews")]
    public class EpisodeReviewController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;

        public EpisodeReviewController(
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
        /// Get all reviews for an episode
        /// </summary>
        [HttpGet("episode/{episodeId}")]
        [AllowAnonymous]
        [SwaggerOperation(Summary = "Get episode reviews", Description = "Gets all reviews for a specific episode. Public endpoint - no authentication required.")]
        public async Task<IActionResult> GetEpisodeReviews(int episodeId)
        {
            var reviews = await _context.EpisodeReviews
                .Include(er => er.User)
                .Include(er => er.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .Where(er => er.EpisodeId == episodeId)
                .OrderByDescending(er => er.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<EpisodeReviewDto>>(reviews);
            return Ok(result);
        }

        /// <summary>
        /// Get current user's review for an episode
        /// </summary>
        [HttpGet("episode/{episodeId}/my-review")]
        [SwaggerOperation(Summary = "Get my review", Description = "Gets the current user's review for an episode.")]
        public async Task<IActionResult> GetMyReview(int episodeId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var review = await _context.EpisodeReviews
                .Include(er => er.User)
                .Include(er => er.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(er => er.UserId == currentUserId.Value && er.EpisodeId == episodeId);

            if (review == null)
            {
                return NotFound(new { message = "Review not found." });
            }

            var result = _mapper.Map<EpisodeReviewDto>(review);
            return Ok(result);
        }

        /// <summary>
        /// Checks if a user has completed watching all episodes in a series
        /// </summary>
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

        /// <summary>
        /// Create or update a review for an episode
        /// </summary>
        [HttpPost]
        [SwaggerOperation(Summary = "Create review", Description = "Creates a new review for an episode. User must have completed the entire series.")]
        public async Task<IActionResult> CreateReview([FromBody] EpisodeReviewCreateDto dto)
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

            // Validate that user has completed the entire series before allowing review
            var seriesId = episode.Season.SeriesId;
            var hasCompleted = await HasUserCompletedSeries(currentUserId.Value, seriesId);
            if (!hasCompleted)
            {
                return BadRequest(new { message = "You can only leave a review after completing the entire series." });
            }

            // Check if review already exists
            var existingReview = await _context.EpisodeReviews
                .FirstOrDefaultAsync(er => er.UserId == currentUserId.Value && er.EpisodeId == dto.EpisodeId);

            if (existingReview != null)
            {
                // Update existing review
                existingReview.Rating = dto.Rating;
                existingReview.ReviewText = dto.ReviewText;
                existingReview.IsAnonymous = dto.IsAnonymous;
                existingReview.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                // Create new review
                var review = new EpisodeReview
                {
                    UserId = currentUserId.Value,
                    EpisodeId = dto.EpisodeId,
                    Rating = dto.Rating,
                    ReviewText = dto.ReviewText,
                    IsAnonymous = dto.IsAnonymous,
                    CreatedAt = DateTime.UtcNow
                };
                _context.EpisodeReviews.Add(review);
            }

            await _context.SaveChangesAsync();

            // Return updated review
            var updatedReview = await _context.EpisodeReviews
                .Include(er => er.User)
                .Include(er => er.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(er => er.UserId == currentUserId.Value && er.EpisodeId == dto.EpisodeId);

            var result = _mapper.Map<EpisodeReviewDto>(updatedReview);
            return Ok(result);
        }

        /// <summary>
        /// Update an existing review
        /// </summary>
        [HttpPut("{reviewId}")]
        [SwaggerOperation(Summary = "Update review", Description = "Updates an existing review. User must have completed the entire series.")]
        public async Task<IActionResult> UpdateReview(int reviewId, [FromBody] EpisodeReviewUpdateDto dto)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var review = await _context.EpisodeReviews
                .Include(er => er.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(er => er.Id == reviewId && er.UserId == currentUserId.Value);

            if (review == null)
            {
                return NotFound(new { message = "Review not found." });
            }

            // Validate that user has completed the entire series before allowing review update
            var seriesId = review.Episode.Season.SeriesId;
            var hasCompleted = await HasUserCompletedSeries(currentUserId.Value, seriesId);
            if (!hasCompleted)
            {
                return BadRequest(new { message = "You can only update a review after completing the entire series." });
            }

            review.Rating = dto.Rating;
            review.ReviewText = dto.ReviewText;
            review.IsAnonymous = dto.IsAnonymous;
            review.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            var updatedReview = await _context.EpisodeReviews
                .Include(er => er.User)
                .Include(er => er.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .FirstOrDefaultAsync(er => er.Id == reviewId);

            var result = _mapper.Map<EpisodeReviewDto>(updatedReview);
            return Ok(result);
        }

        /// <summary>
        /// Delete a review
        /// </summary>
        [HttpDelete("{reviewId}")]
        [SwaggerOperation(Summary = "Delete review", Description = "Deletes a review.")]
        public async Task<IActionResult> DeleteReview(int reviewId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var review = await _context.EpisodeReviews
                .FirstOrDefaultAsync(er => er.Id == reviewId && er.UserId == currentUserId.Value);

            if (review == null)
            {
                return NotFound(new { message = "Review not found." });
            }

            _context.EpisodeReviews.Remove(review);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Review deleted successfully." });
        }

        /// <summary>
        /// Get all reviews (admin only)
        /// </summary>
        [HttpGet("all")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Get all reviews", Description = "Admin only. Gets all reviews from all users.")]
        public async Task<IActionResult> GetAllReviews()
        {
            try
            {
                // First, get all reviews with basic includes
                var reviews = await _context.EpisodeReviews
                    .AsSplitQuery()
                    .Include(er => er.User)
                    .Include(er => er.Episode)
                        .ThenInclude(e => e.Season)
                            .ThenInclude(s => s.Series)
                    .OrderByDescending(er => er.CreatedAt)
                    .ToListAsync();

                // Filter out any reviews with null navigation properties (orphaned data)
                var validReviews = reviews
                    .Where(er => er.Episode != null && 
                                 er.User != null && 
                                 er.Episode.Season != null && 
                                 er.Episode.Season.Series != null)
                    .ToList();

                // Map to DTOs
                var result = _mapper.Map<IEnumerable<EpisodeReviewDto>>(validReviews);
                return Ok(result);
            }
            catch (Exception ex)
            {
                // Log the full exception
                var errorDetails = new
                {
                    message = ex.Message,
                    innerException = ex.InnerException?.Message,
                    stackTrace = ex.StackTrace,
                    source = ex.Source
                };

                // Return detailed error - this will help us debug
                return StatusCode(500, new { 
                    statusCode = 500,
                    message = $"Error loading reviews: {ex.Message}",
                    details = errorDetails
                });
            }
        }

        /// <summary>
        /// Get all reviews by current user
        /// </summary>
        [HttpGet("my-reviews")]
        [SwaggerOperation(Summary = "Get my reviews", Description = "Gets all reviews by the current user.")]
        public async Task<IActionResult> GetMyReviews()
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var reviews = await _context.EpisodeReviews
                .Include(er => er.User)
                .Include(er => er.Episode)
                    .ThenInclude(e => e.Season)
                        .ThenInclude(s => s.Series)
                .Where(er => er.UserId == currentUserId.Value)
                .OrderByDescending(er => er.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<EpisodeReviewDto>>(reviews);
            return Ok(result);
        }
    }
}

