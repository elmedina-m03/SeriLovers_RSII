using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using SeriLovers.API.Services;
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
        private readonly ChallengeService _challengeService;

        public ChallengesController(ApplicationDbContext context, ChallengeService challengeService)
        {
            _context = context;
            _challengeService = challengeService;
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
            // Get total series count to validate ProgressCount
            var totalSeriesCount = await _context.Series.CountAsync();
            
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
                    // Cap ProgressCount at total series count (data integrity fix)
                    watchedSeries = cp.ProgressCount > totalSeriesCount ? totalSeriesCount : cp.ProgressCount,
                    goal = cp.Challenge != null ? cp.Challenge.TargetCount : 0,
                    // Cap progress percentage at 100% (max is 100%)
                    progress = cp.Challenge != null && cp.Challenge.TargetCount > 0
                        ? Math.Min(100, (int)((cp.ProgressCount > totalSeriesCount ? totalSeriesCount : cp.ProgressCount) * 100.0 / cp.Challenge.TargetCount))
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
            var allRatings = await _context.Ratings
                .Include(r => r.User)
                .ToListAsync();
            
            var allWatchlists = await _context.Watchlists
                .Include(w => w.User)
                .ToListAsync();
            
            var realRatings = allRatings
                .Where(r => r.User != null
                    && r.User.Email != null
                    && !r.User.Email.EndsWith("@test.com", StringComparison.OrdinalIgnoreCase)
                    && !r.User.Email.EndsWith("@example.com", StringComparison.OrdinalIgnoreCase)
                    && !r.User.Email.EndsWith("@test", StringComparison.OrdinalIgnoreCase)
                    && !r.User.Email.StartsWith("testuser", StringComparison.OrdinalIgnoreCase))
                .ToList();
            
            var realWatchlists = allWatchlists
                .Where(w => w.User != null
                    && w.User.Email != null
                    && !w.User.Email.EndsWith("@test.com", StringComparison.OrdinalIgnoreCase)
                    && !w.User.Email.EndsWith("@example.com", StringComparison.OrdinalIgnoreCase)
                    && !w.User.Email.EndsWith("@test", StringComparison.OrdinalIgnoreCase)
                    && !w.User.Email.StartsWith("testuser", StringComparison.OrdinalIgnoreCase))
                .ToList();
            
            var ratingsByUser = realRatings
                .GroupBy(r => r.UserId)
                .Select(g => new { UserId = g.Key, Count = g.Count() })
                .ToList();
            
            var watchlistsByUser = realWatchlists
                .GroupBy(w => w.UserId)
                .Select(g => new { UserId = g.Key, Count = g.Count() })
                .ToList();
            
            var ratingsDict = ratingsByUser.ToDictionary(r => r.UserId, r => r.Count);
            var watchlistsDict = watchlistsByUser.ToDictionary(w => w.UserId, w => w.Count);
            
            var allUsers = await _context.Users
                .Select(user => new
                {
                    id = user.Id,
                    email = user.Email ?? "Unknown",
                    userName = user.UserName ?? "Unknown"
                })
                .ToListAsync();
            
            var realUsers = allUsers
                .Where(u => u.email != "Unknown"
                    && !u.email.EndsWith("@test.com", StringComparison.OrdinalIgnoreCase)
                    && !u.email.EndsWith("@example.com", StringComparison.OrdinalIgnoreCase)
                    && !u.email.EndsWith("@test", StringComparison.OrdinalIgnoreCase)
                    && !u.email.StartsWith("testuser", StringComparison.OrdinalIgnoreCase))
                .ToList();
            
            var topWatchersList = new List<object>();
            foreach (var user in realUsers)
            {
                var watchedSeriesCount = await _challengeService.GetCompletedSeriesCountAsync(user.id);
                var ratingsCount = ratingsDict.ContainsKey(user.id) ? ratingsDict[user.id] : 0;
                var watchlistCount = watchlistsDict.ContainsKey(user.id) ? watchlistsDict[user.id] : 0;
                
                topWatchersList.Add(new
                {
                    id = user.id,
                    email = user.email,
                    userName = user.userName,
                    watchedSeriesCount = watchedSeriesCount,
                    ratingsCount = ratingsCount,
                    watchlistCount = watchlistCount,
                    totalActivity = watchedSeriesCount + ratingsCount + watchlistCount
                });
            }
            
            var topWatchers = topWatchersList
                .OrderByDescending(u => ((dynamic)u).totalActivity)
                .Take(3)
                .ToList();

            // Get participants count per challenge
            var participantsCounts = await _context.ChallengeProgresses
                .GroupBy(cp => cp.ChallengeId)
                .Select(g => new
                {
                    ChallengeId = g.Key,
                    ParticipantsCount = g.Count()
                })
                .ToListAsync();
            
            var allChallenges = await _context.Challenges.ToListAsync();
            var participantsCountsDict = allChallenges
                .Select(c => new
                {
                    ChallengeId = c.Id,
                    ParticipantsCount = participantsCounts.FirstOrDefault(p => p.ChallengeId == c.Id)?.ParticipantsCount ?? 0
                })
                .ToList();

            // Update Challenges.ParticipantsCount if needed
            foreach (var pc in participantsCountsDict)
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
                participantsCounts = participantsCountsDict.ToDictionary(pc => pc.ChallengeId, pc => pc.ParticipantsCount)
            };

            return Ok(result);
        }

        /// <summary>
        /// Recalculate all challenge progress for all users (fixes corrupted data)
        /// </summary>
        [HttpPost("recalculate-all")]
        [SwaggerOperation(
            Summary = "Recalculate all challenge progress",
            Description = "Recalculates challenge progress for all users based on real EpisodeProgress data. Fixes corrupted ProgressCount values. Admin only.")]
        public async Task<IActionResult> RecalculateAllProgress()
        {
            var challengeService = new ChallengeService(_context);
            var allUsers = await _context.Users.Select(u => u.Id).ToListAsync();
            
            int updatedCount = 0;
            foreach (var userId in allUsers)
            {
                try
                {
                    await challengeService.UpdateChallengeProgressAsync(userId);
                    updatedCount++;
                }
                catch (Exception)
                {
                    // Ignore individual user update failures
                }
            }

            return Ok(new { 
                message = $"Recalculated challenge progress for {updatedCount} users.",
                usersProcessed = updatedCount,
                totalUsers = allUsers.Count
            });
        }
    }
}

