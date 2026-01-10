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
        /// DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.
        /// </summary>
        [HttpGet("episode/{episodeId}")]
        [AllowAnonymous]
        [SwaggerOperation(Summary = "Get episode reviews", Description = "DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.")]
        public IActionResult GetEpisodeReviews(int episodeId)
        {
            return StatusCode(410, new { message = "Episode reviews are no longer supported. Reviews are only allowed for entire series. Please use the Rating API for series-level reviews." });
        }

        /// <summary>
        /// Get current user's review for an episode
        /// DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.
        /// </summary>
        [HttpGet("episode/{episodeId}/my-review")]
        [SwaggerOperation(Summary = "Get my review", Description = "DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.")]
        public IActionResult GetMyReview(int episodeId)
        {
            return StatusCode(410, new { message = "Episode reviews are no longer supported. Reviews are only allowed for entire series. Please use the Rating API for series-level reviews." });
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
        /// DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.
        /// </summary>
        [HttpPost]
        [SwaggerOperation(Summary = "Create review", Description = "DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.")]
        public IActionResult CreateReview([FromBody] EpisodeReviewCreateDto dto)
        {
            return StatusCode(410, new { message = "Episode reviews are no longer supported. Reviews are only allowed for entire series. Please use the Rating API for series-level reviews." });
        }

        /// <summary>
        /// Update an existing review
        /// DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.
        /// </summary>
        [HttpPut("{reviewId}")]
        [SwaggerOperation(Summary = "Update review", Description = "DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.")]
        public IActionResult UpdateReview(int reviewId, [FromBody] EpisodeReviewUpdateDto dto)
        {
            return StatusCode(410, new { message = "Episode reviews are no longer supported. Reviews are only allowed for entire series. Please use the Rating API for series-level reviews." });
        }

        /// <summary>
        /// Delete a review
        /// DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.
        /// </summary>
        [HttpDelete("{reviewId}")]
        [SwaggerOperation(Summary = "Delete review", Description = "DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.")]
        public IActionResult DeleteReview(int reviewId)
        {
            return StatusCode(410, new { message = "Episode reviews are no longer supported. Reviews are only allowed for entire series. Please use the Rating API for series-level reviews." });
        }

        /// <summary>
        /// Get all reviews (admin only)
        /// DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.
        /// </summary>
        [HttpGet("all")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Get all reviews", Description = "DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.")]
        public IActionResult GetAllReviews()
        {
            return StatusCode(410, new { message = "Episode reviews are no longer supported. Reviews are only allowed for entire series. Please use the Rating API for series-level reviews." });
        }

        /// <summary>
        /// Get all reviews by current user
        /// DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.
        /// </summary>
        [HttpGet("my-reviews")]
        [SwaggerOperation(Summary = "Get my reviews", Description = "DEPRECATED: Episode reviews are no longer supported. Reviews are only allowed for entire series.")]
        public IActionResult GetMyReviews()
        {
            return StatusCode(410, new { message = "Episode reviews are no longer supported. Reviews are only allowed for entire series. Please use the Rating API for series-level reviews." });
        }
    }
}

