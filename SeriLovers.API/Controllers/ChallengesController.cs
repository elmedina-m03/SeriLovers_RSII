using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Linq;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Public controller for challenges that users can see and participate in
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Challenges (Public)")]
    public class ChallengesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;

        public ChallengesController(ApplicationDbContext context, UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        /// <summary>
        /// Get all available challenges (public endpoint)
        /// </summary>
        [HttpGet]
        [AllowAnonymous]
        [SwaggerOperation(
            Summary = "Get all challenges",
            Description = "Retrieves a list of all available challenges that users can participate in.")]
        public async Task<IActionResult> GetAll()
        {
            var challenges = await _context.Challenges
                .OrderByDescending(c => c.CreatedAt)
                .Select(c => new ChallengeDto
                {
                    Id = c.Id,
                    Name = c.Name,
                    Description = c.Description,
                    Difficulty = c.Difficulty,
                    TargetCount = c.TargetCount,
                    ParticipantsCount = c.ParticipantsCount,
                    CreatedAt = c.CreatedAt
                })
                .ToListAsync();

            return Ok(challenges);
        }

        /// <summary>
        /// Get user's challenge progress
        /// </summary>
        [HttpGet("my-progress")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Get my challenge progress",
            Description = "Retrieves all challenges with the current user's progress.")]
        public async Task<IActionResult> GetMyProgress()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var challenges = await _context.Challenges
                .Select(c => new
                {
                    Challenge = new ChallengeDto
                    {
                        Id = c.Id,
                        Name = c.Name,
                        Description = c.Description,
                        Difficulty = c.Difficulty,
                        TargetCount = c.TargetCount,
                        ParticipantsCount = c.ParticipantsCount,
                        CreatedAt = c.CreatedAt
                    },
                    Progress = _context.ChallengeProgresses
                        .Where(cp => cp.ChallengeId == c.Id && cp.UserId == user.Id)
                        .Select(cp => new
                        {
                            ProgressCount = cp.ProgressCount,
                            Status = cp.Status.ToString(),
                            CompletedAt = cp.CompletedAt
                        })
                        .FirstOrDefault()
                })
                .ToListAsync();

            return Ok(challenges);
        }

        /// <summary>
        /// Start a challenge (create challenge progress)
        /// </summary>
        [HttpPost("{challengeId}/start")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Start a challenge",
            Description = "Allows the current user to start participating in a challenge.")]
        public async Task<IActionResult> StartChallenge(int challengeId)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var challenge = await _context.Challenges.FindAsync(challengeId);
            if (challenge == null)
            {
                return NotFound(new { error = $"Challenge with ID {challengeId} not found." });
            }

            // Check if user already has progress for this challenge
            var existingProgress = await _context.ChallengeProgresses
                .FirstOrDefaultAsync(cp => cp.ChallengeId == challengeId && cp.UserId == user.Id);

            if (existingProgress != null)
            {
                return BadRequest(new { error = "You have already started this challenge." });
            }

            // Create new challenge progress
            var progress = new ChallengeProgress
            {
                ChallengeId = challengeId,
                UserId = user.Id,
                ProgressCount = 0,
                Status = ChallengeProgressStatus.InProgress
            };

            _context.ChallengeProgresses.Add(progress);

            // Update challenge participants count
            challenge.ParticipantsCount = await _context.ChallengeProgresses
                .CountAsync(cp => cp.ChallengeId == challengeId);

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Challenge started successfully",
                progress = new
                {
                    progressCount = progress.ProgressCount,
                    status = progress.Status.ToString()
                }
            });
        }

        /// <summary>
        /// Update challenge progress
        /// </summary>
        [HttpPut("{challengeId}/progress")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Update challenge progress",
            Description = "Updates the user's progress for a specific challenge.")]
        public async Task<IActionResult> UpdateProgress(int challengeId, [FromBody] int progressCount)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var progress = await _context.ChallengeProgresses
                .FirstOrDefaultAsync(cp => cp.ChallengeId == challengeId && cp.UserId == user.Id);

            if (progress == null)
            {
                return NotFound(new { error = "You have not started this challenge yet." });
            }

            var challenge = await _context.Challenges.FindAsync(challengeId);
            if (challenge == null)
            {
                return NotFound(new { error = $"Challenge with ID {challengeId} not found." });
            }

            progress.ProgressCount = progressCount;

            // Check if challenge is completed
            if (progressCount >= challenge.TargetCount && progress.Status != ChallengeProgressStatus.Completed)
            {
                progress.Status = ChallengeProgressStatus.Completed;
                progress.CompletedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Progress updated successfully",
                progress = new
                {
                    progressCount = progress.ProgressCount,
                    status = progress.Status.ToString(),
                    completedAt = progress.CompletedAt
                }
            });
        }
    }
}

