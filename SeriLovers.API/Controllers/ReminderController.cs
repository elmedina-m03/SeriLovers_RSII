using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
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

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Manages user reminders for series - notifications when new episodes are added.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Reminders")]
    public class ReminderController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;

        public ReminderController(
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
        /// Get all reminders for the current user
        /// </summary>
        [HttpGet]
        [SwaggerOperation(Summary = "Get all reminders", Description = "Retrieves all reminders for the current authenticated user.")]
        public async Task<ActionResult<IEnumerable<UserSeriesReminderDto>>> GetAll()
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var reminders = await _context.UserSeriesReminders
                .AsNoTracking()
                .Include(r => r.Series)
                .Where(r => r.UserId == currentUserId.Value)
                .OrderByDescending(r => r.EnabledAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<UserSeriesReminderDto>>(reminders);
            return Ok(result);
        }

        /// <summary>
        /// Check if reminder is enabled for a specific series
        /// </summary>
        [HttpGet("series/{seriesId}")]
        [SwaggerOperation(Summary = "Check reminder status", Description = "Checks if a reminder is enabled for a specific series for the current user.")]
        public async Task<ActionResult<bool>> GetReminderStatus(int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var reminderExists = await _context.UserSeriesReminders
                .AsNoTracking()
                .AnyAsync(r => r.UserId == currentUserId.Value && r.SeriesId == seriesId);

            return Ok(reminderExists);
        }

        /// <summary>
        /// Enable reminder for a series
        /// </summary>
        [HttpPost]
        [SwaggerOperation(Summary = "Enable reminder", Description = "Enables a reminder for a series. User will be notified when new episodes are added.")]
        public async Task<ActionResult<UserSeriesReminderDto>> EnableReminder([FromBody] UserSeriesReminderCreateDto dto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            // Check if series exists
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == dto.SeriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {dto.SeriesId} not found." });
            }

            // Check if reminder already exists
            var existingReminder = await _context.UserSeriesReminders
                .FirstOrDefaultAsync(r => r.UserId == currentUserId.Value && r.SeriesId == dto.SeriesId);

            if (existingReminder != null)
            {
                // Reminder already exists, return it
                await _context.Entry(existingReminder).Reference(r => r.Series).LoadAsync();
                var result = _mapper.Map<UserSeriesReminderDto>(existingReminder);
                return Ok(result);
            }

            // Count current episodes in the series
            var currentEpisodeCount = await _context.Series
                .Where(s => s.Id == dto.SeriesId)
                .SelectMany(s => s.Seasons)
                .SelectMany(season => season.Episodes)
                .CountAsync();

            // Create new reminder
            var reminder = new UserSeriesReminder
            {
                UserId = currentUserId.Value,
                SeriesId = dto.SeriesId,
                LastEpisodeCount = currentEpisodeCount,
                EnabledAt = DateTime.UtcNow,
                LastCheckedAt = DateTime.UtcNow
            };

            _context.UserSeriesReminders.Add(reminder);
            await _context.SaveChangesAsync();

            await _context.Entry(reminder).Reference(r => r.Series).LoadAsync();
            var reminderDto = _mapper.Map<UserSeriesReminderDto>(reminder);
            return CreatedAtAction(nameof(GetReminderStatus), new { seriesId = dto.SeriesId }, reminderDto);
        }

        /// <summary>
        /// Disable reminder for a series
        /// </summary>
        [HttpDelete("series/{seriesId}")]
        [SwaggerOperation(Summary = "Disable reminder", Description = "Disables a reminder for a series.")]
        public async Task<IActionResult> DisableReminder(int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var reminder = await _context.UserSeriesReminders
                .FirstOrDefaultAsync(r => r.UserId == currentUserId.Value && r.SeriesId == seriesId);

            if (reminder == null)
            {
                return NotFound(new { message = "Reminder not found." });
            }

            _context.UserSeriesReminders.Remove(reminder);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}

