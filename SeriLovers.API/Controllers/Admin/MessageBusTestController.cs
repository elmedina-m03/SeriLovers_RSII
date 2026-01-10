using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Hosting;
using SeriLovers.API.Events;
using SeriLovers.API.Interfaces;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers.Admin
{
    /// <summary>
    /// Test endpoint to verify RabbitMQ functionality (Development only)
    /// </summary>
    [ApiController]
    [Route("api/admin/[controller]")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("Admin - Message Bus Testing (Development Only)")]
    public class MessageBusTestController : ControllerBase
    {
        private readonly IMessageBusService _messageBusService;
        private readonly ILogger<MessageBusTestController> _logger;
        private readonly IWebHostEnvironment _environment;

        public MessageBusTestController(
            IMessageBusService messageBusService,
            ILogger<MessageBusTestController> logger,
            IWebHostEnvironment environment)
        {
            _messageBusService = messageBusService;
            _logger = logger;
            _environment = environment;
        }

        /// <summary>
        /// Checks if the controller is available (only in Development)
        /// </summary>
        private IActionResult? CheckDevelopmentOnly()
        {
            if (!_environment.IsDevelopment())
            {
                return NotFound(new { message = "This endpoint is only available in Development environment." });
            }
            return null;
        }

        /// <summary>
        /// Check RabbitMQ connection status
        /// </summary>
        [HttpGet("status")]
        [SwaggerOperation(Summary = "Check RabbitMQ status", Description = "Returns whether RabbitMQ is available and connected. (Development only)")]
        public IActionResult GetStatus()
        {
            var devCheck = CheckDevelopmentOnly();
            if (devCheck != null) return devCheck;

            var status = new
            {
                IsAvailable = _messageBusService.IsAvailable,
                Message = _messageBusService.IsAvailable 
                    ? "RabbitMQ is connected and available" 
                    : "RabbitMQ is not available. Check your connection string in appsettings.json or environment variables."
            };

            return Ok(status);
        }

        /// <summary>
        /// Test publishing a ReviewCreatedEvent
        /// </summary>
        [HttpPost("test/review-created")]
        [SwaggerOperation(Summary = "Test ReviewCreatedEvent", Description = "Publishes a test ReviewCreatedEvent to verify RabbitMQ publishing works. (Development only)")]
        public async Task<IActionResult> TestReviewCreated()
        {
            var devCheck = CheckDevelopmentOnly();
            if (devCheck != null) return devCheck;

            if (!_messageBusService.IsAvailable)
            {
                return BadRequest(new { message = "RabbitMQ is not available. Cannot publish test event." });
            }

            try
            {
                var testEvent = new ReviewCreatedEvent
                {
                    RatingId = 999,
                    UserId = 1,
                    UserName = "TestUser",
                    SeriesId = 1,
                    SeriesTitle = "Test Series",
                    Score = 5,
                    Comment = "This is a test review event",
                    CreatedAt = DateTime.UtcNow
                };

                await _messageBusService.PublishEventAsync(testEvent);

                return Ok(new
                {
                    message = "Test ReviewCreatedEvent published successfully. Check your application logs for '[RabbitMQ] ReviewCreatedEvent received' message.",
                    eventData = testEvent
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish test ReviewCreatedEvent");
                return StatusCode(500, new { message = "Failed to publish test event", error = ex.Message });
            }
        }

        /// <summary>
        /// Test publishing an EpisodeWatchedEvent
        /// </summary>
        [HttpPost("test/episode-watched")]
        [SwaggerOperation(Summary = "Test EpisodeWatchedEvent", Description = "Publishes a test EpisodeWatchedEvent to verify RabbitMQ publishing works. (Development only)")]
        public async Task<IActionResult> TestEpisodeWatched()
        {
            var devCheck = CheckDevelopmentOnly();
            if (devCheck != null) return devCheck;

            if (!_messageBusService.IsAvailable)
            {
                return BadRequest(new { message = "RabbitMQ is not available. Cannot publish test event." });
            }

            try
            {
                var testEvent = new EpisodeWatchedEvent
                {
                    EpisodeId = 1,
                    EpisodeNumber = 1,
                    SeasonId = 1,
                    SeasonNumber = 1,
                    SeriesId = 1,
                    SeriesTitle = "Test Series",
                    UserId = 1,
                    UserName = "TestUser",
                    IsCompleted = true,
                    WatchedAt = DateTime.UtcNow
                };

                await _messageBusService.PublishEventAsync(testEvent);

                return Ok(new
                {
                    message = "Test EpisodeWatchedEvent published successfully. Check your application logs for '[RabbitMQ] EpisodeWatchedEvent received' message.",
                    eventData = testEvent
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish test EpisodeWatchedEvent");
                return StatusCode(500, new { message = "Failed to publish test event", error = ex.Message });
            }
        }

        /// <summary>
        /// Test publishing a UserCreatedEvent
        /// </summary>
        [HttpPost("test/user-created")]
        [SwaggerOperation(Summary = "Test UserCreatedEvent", Description = "Publishes a test UserCreatedEvent to verify RabbitMQ publishing works. (Development only)")]
        public async Task<IActionResult> TestUserCreated()
        {
            var devCheck = CheckDevelopmentOnly();
            if (devCheck != null) return devCheck;

            if (!_messageBusService.IsAvailable)
            {
                return BadRequest(new { message = "RabbitMQ is not available. Cannot publish test event." });
            }

            try
            {
                var testEvent = new UserCreatedEvent
                {
                    UserId = 999,
                    Email = "test@example.com",
                    UserName = "TestUser",
                    CreatedAt = DateTime.UtcNow
                };

                await _messageBusService.PublishEventAsync(testEvent);

                return Ok(new
                {
                    message = "Test UserCreatedEvent published successfully. Check your application logs for '[RabbitMQ] UserCreatedEvent received' message.",
                    eventData = testEvent
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish test UserCreatedEvent");
                return StatusCode(500, new { message = "Failed to publish test event", error = ex.Message });
            }
        }

        /// <summary>
        /// Test publishing a UserUpdatedEvent
        /// </summary>
        [HttpPost("test/user-updated")]
        [SwaggerOperation(Summary = "Test UserUpdatedEvent", Description = "Publishes a test UserUpdatedEvent to verify RabbitMQ publishing works. (Development only)")]
        public async Task<IActionResult> TestUserUpdated()
        {
            var devCheck = CheckDevelopmentOnly();
            if (devCheck != null) return devCheck;

            if (!_messageBusService.IsAvailable)
            {
                return BadRequest(new { message = "RabbitMQ is not available. Cannot publish test event." });
            }

            try
            {
                var testEvent = new UserUpdatedEvent
                {
                    UserId = 1,
                    UserName = "TestUser",
                    Email = "test@example.com",
                    Country = "Test Country",
                    AvatarUrl = "https://example.com/avatar.jpg",
                    UpdatedAt = DateTime.UtcNow
                };

                await _messageBusService.PublishEventAsync(testEvent);

                return Ok(new
                {
                    message = "Test UserUpdatedEvent published successfully. Check your application logs for '[RabbitMQ] UserUpdatedEvent received' message.",
                    eventData = testEvent
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to publish test UserUpdatedEvent");
                return StatusCode(500, new { message = "Failed to publish test event", error = ex.Message });
            }
        }
    }
}
