using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers.Admin
{
    /// <summary>
    /// Admin controller for managing challenges
    /// </summary>
    [ApiController]
    [Route("api/Admin/[controller]")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("Challenge Management (Admin Only)")]
    public class ChallengesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public ChallengesController(ApplicationDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Get all challenges
        /// </summary>
        [HttpGet]
        [SwaggerOperation(
            Summary = "Get all challenges",
            Description = "Retrieves a list of all challenges. Admin only.")]
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
        /// Get all user challenge progress
        /// </summary>
        [HttpGet("progress")]
        [SwaggerOperation(
            Summary = "Get all user challenge progress",
            Description = "Retrieves all user challenge progress with user details. Admin only.")]
        public async Task<IActionResult> GetAllProgress()
        {
            var progressList = await _context.ChallengeProgresses
                .Include(cp => cp.User)
                .Include(cp => cp.Challenge)
                .Select(cp => new
                {
                    id = cp.Id,
                    userId = cp.UserId,
                    userName = cp.User != null ? (cp.User.UserName ?? cp.User.Email ?? "Unknown") : "Unknown",
                    userEmail = cp.User != null ? (cp.User.Email ?? "Unknown") : "Unknown",
                    challengeId = cp.ChallengeId,
                    challengeName = cp.Challenge != null ? cp.Challenge.Name : "Unknown",
                    watchedSeries = cp.ProgressCount,
                    goal = cp.Challenge != null ? cp.Challenge.TargetCount : 0,
                    progress = cp.Challenge != null && cp.Challenge.TargetCount > 0
                        ? (int)((cp.ProgressCount * 100.0) / cp.Challenge.TargetCount)
                        : 0,
                    status = cp.Status == ChallengeProgressStatus.Completed ? "Completed" : "Processing"
                })
                .OrderByDescending(p => p.watchedSeries)
                .ToListAsync();

            return Ok(progressList);
        }

        /// <summary>
        /// Get a challenge by ID
        /// </summary>
        [HttpGet("{id}")]
        [SwaggerOperation(
            Summary = "Get challenge by ID",
            Description = "Retrieves a specific challenge by its ID. Admin only.")]
        public async Task<IActionResult> GetById(int id)
        {
            var challenge = await _context.Challenges
                .Where(c => c.Id == id)
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
                .FirstOrDefaultAsync();

            if (challenge == null)
            {
                return NotFound(new { error = $"Challenge with ID {id} not found." });
            }

            return Ok(challenge);
        }

        /// <summary>
        /// Create a new challenge
        /// </summary>
        [HttpPost]
        [SwaggerOperation(
            Summary = "Create a new challenge",
            Description = "Creates a new challenge. Admin only.")]
        public async Task<IActionResult> Create([FromBody] ChallengeCreateDto createDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var challenge = new Challenge
            {
                Name = createDto.Name,
                Description = createDto.Description,
                Difficulty = createDto.Difficulty,
                TargetCount = createDto.TargetCount,
                ParticipantsCount = 0,
                CreatedAt = DateTime.UtcNow
            };

            _context.Challenges.Add(challenge);
            await _context.SaveChangesAsync();

            var challengeDto = new ChallengeDto
            {
                Id = challenge.Id,
                Name = challenge.Name,
                Description = challenge.Description,
                Difficulty = challenge.Difficulty,
                TargetCount = challenge.TargetCount,
                ParticipantsCount = challenge.ParticipantsCount,
                CreatedAt = challenge.CreatedAt
            };

            return CreatedAtAction(nameof(GetById), new { id = challenge.Id }, challengeDto);
        }

        /// <summary>
        /// Update an existing challenge
        /// </summary>
        [HttpPut("{id}")]
        [SwaggerOperation(
            Summary = "Update a challenge",
            Description = "Updates an existing challenge. Admin only.")]
        public async Task<IActionResult> Update(int id, [FromBody] ChallengeUpdateDto updateDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            var challenge = await _context.Challenges.FindAsync(id);
            if (challenge == null)
            {
                return NotFound(new { error = $"Challenge with ID {id} not found." });
            }

            challenge.Name = updateDto.Name;
            challenge.Description = updateDto.Description;
            challenge.Difficulty = updateDto.Difficulty;
            challenge.TargetCount = updateDto.TargetCount;

            await _context.SaveChangesAsync();

            var challengeDto = new ChallengeDto
            {
                Id = challenge.Id,
                Name = challenge.Name,
                Description = challenge.Description,
                Difficulty = challenge.Difficulty,
                TargetCount = challenge.TargetCount,
                ParticipantsCount = challenge.ParticipantsCount,
                CreatedAt = challenge.CreatedAt
            };

            return Ok(challengeDto);
        }

        /// <summary>
        /// Delete a challenge
        /// </summary>
        [HttpDelete("{id}")]
        [SwaggerOperation(
            Summary = "Delete a challenge",
            Description = "Deletes a challenge by ID. Admin only.")]
        public async Task<IActionResult> Delete(int id)
        {
            var challenge = await _context.Challenges.FindAsync(id);
            if (challenge == null)
            {
                return NotFound(new { error = $"Challenge with ID {id} not found." });
            }

            _context.Challenges.Remove(challenge);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        /// <summary>
        /// Get challenges summary including top 3 watchers and participants counts
        /// </summary>
        [HttpGet("summary")]
        [SwaggerOperation(
            Summary = "Get challenges summary",
            Description = "Returns top 3 watchers and participants counts for challenges. Admin only.")]
        public async Task<IActionResult> GetSummary()
        {
            // Get top 3 watchers (users with most ratings + watchlist entries)
            var topWatchers = await _context.Users
                .Select(u => new
                {
                    UserId = u.Id,
                    Email = u.Email ?? "Unknown",
                    UserName = u.UserName ?? "Unknown",
                    RatingsCount = _context.Ratings.Count(r => r.UserId == u.Id),
                    WatchlistCount = _context.Watchlists.Count(w => w.UserId == u.Id),
                    TotalActivity = _context.Ratings.Count(r => r.UserId == u.Id) +
                                   _context.Watchlists.Count(w => w.UserId == u.Id)
                })
                .OrderByDescending(u => u.TotalActivity)
                .Take(3)
                .Select(u => new
                {
                    id = u.UserId,
                    email = u.Email,
                    userName = u.UserName,
                    ratingsCount = u.RatingsCount,
                    watchlistCount = u.WatchlistCount,
                    totalActivity = u.TotalActivity
                })
                .ToListAsync();

            // Get participants count per challenge
            var participantsCounts = await _context.Challenges
                .Select(c => new
                {
                    ChallengeId = c.Id,
                    ParticipantsCount = _context.ChallengeProgresses.Count(cp => cp.ChallengeId == c.Id)
                })
                .ToListAsync();

            // Update Challenges.ParticipantsCount if needed
            foreach (var pc in participantsCounts)
            {
                var challenge = await _context.Challenges.FindAsync(pc.ChallengeId);
                if (challenge != null && challenge.ParticipantsCount != pc.ParticipantsCount)
                {
                    challenge.ParticipantsCount = pc.ParticipantsCount;
                }
            }
            await _context.SaveChangesAsync();

            var result = new
            {
                topWatchers = topWatchers,
                participantsCounts = participantsCounts.ToDictionary(pc => pc.ChallengeId, pc => pc.ParticipantsCount)
            };

            return Ok(result);
        }
    }
}

