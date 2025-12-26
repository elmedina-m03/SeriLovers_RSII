using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using SeriLovers.API.Services;
using Swashbuckle.AspNetCore.Annotations;
using System.Threading.Tasks;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Provides personalized TV series recommendations using content-based filtering
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Recommendations")]
    public class RecommendationsController : ControllerBase
    {
        private readonly RecommendationService _recommendationService;
        private readonly UserManager<ApplicationUser> _userManager;

        public RecommendationsController(
            RecommendationService recommendationService,
            UserManager<ApplicationUser> userManager)
        {
            _recommendationService = recommendationService;
            _userManager = userManager;
        }

        /// <summary>
        /// Get personalized recommendations for a specific user
        /// </summary>
        /// <param name="userId">The user ID to get recommendations for</param>
        /// <param name="maxResults">Maximum number of recommendations to return (default: 10)</param>
        /// <returns>List of recommended series with similarity scores and reasons</returns>
        /// <remarks>
        /// Sample response:
        /// 
        /// ```
        /// [
        ///   {
        ///     "id": 1,
        ///     "title": "Breaking Bad",
        ///     "imageUrl": "https://...",
        ///     "genres": ["Crime", "Drama"],
        ///     "averageRating": 9.5,
        ///     "similarityScore": 0.85,
        ///     "reason": "Similar genres: Crime, Drama • Similar rating (9.5/10)"
        ///   }
        /// ]
        /// ```
        /// </remarks>
        [HttpGet("{userId}")]
        [SwaggerOperation(
            Summary = "Get recommendations for user",
            Description = "Returns personalized series recommendations using content-based filtering. Analyzes user's watched/rated series and recommends similar series based on genres, ratings, and description keywords.")]
        public async Task<IActionResult> GetRecommendations(int userId, [FromQuery] int maxResults = 10)
        {
            // Verify user exists
            var user = await _userManager.FindByIdAsync(userId.ToString());
            if (user == null)
            {
                return NotFound(new { message = $"User with ID {userId} not found." });
            }

            // Check if requesting user is the same user or is an admin
            var currentUser = await _userManager.GetUserAsync(User);
            if (currentUser == null)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            if (currentUser.Id != userId && !User.IsInRole("Admin"))
            {
                return Forbid();
            }

            var recommendations = await _recommendationService.GetRecommendationsAsync(userId, maxResults);
            return Ok(recommendations);
        }

        /// <summary>
        /// Get recommendations for the current authenticated user
        /// </summary>
        [HttpGet("me")]
        [SwaggerOperation(
            Summary = "Get my recommendations",
            Description = "Returns personalized series recommendations for the currently authenticated user.")]
        public async Task<IActionResult> GetMyRecommendations([FromQuery] int maxResults = 10)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var recommendations = await _recommendationService.GetRecommendationsAsync(user.Id, maxResults);
            return Ok(recommendations);
        }
    }
}

