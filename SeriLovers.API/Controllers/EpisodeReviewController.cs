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
        [SwaggerOperation(Summary = "Get episode reviews", Description = "Gets all reviews for a specific episode.")]
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
        /// Create or update a review for an episode
        /// </summary>
        [HttpPost]
        [SwaggerOperation(Summary = "Create review", Description = "Creates a new review for an episode.")]
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

            // Check if review already exists
            var existingReview = await _context.EpisodeReviews
                .FirstOrDefaultAsync(er => er.UserId == currentUserId.Value && er.EpisodeId == dto.EpisodeId);

            if (existingReview != null)
            {
                // Update existing review
                existingReview.Rating = dto.Rating;
                existingReview.ReviewText = dto.ReviewText;
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
        [SwaggerOperation(Summary = "Update review", Description = "Updates an existing review.")]
        public async Task<IActionResult> UpdateReview(int reviewId, [FromBody] EpisodeReviewUpdateDto dto)
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

            review.Rating = dto.Rating;
            review.ReviewText = dto.ReviewText;
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

