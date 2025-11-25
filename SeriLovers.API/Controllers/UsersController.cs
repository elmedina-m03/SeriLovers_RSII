using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using System;
using System.Linq;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Provides admin endpoints for managing users.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("User Management (Admin Only)")]
    public class UsersController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ApplicationDbContext _context;

        public UsersController(UserManager<ApplicationUser> userManager, ApplicationDbContext context)
        {
            _userManager = userManager;
            _context = context;
        }

        [HttpGet]
        [SwaggerOperation(
            Summary = "Get all users",
            Description = "Retrieves all users with filtering, search, and sorting. Admin only.")]
        public async Task<IActionResult> GetAll(
            [FromQuery] string? search = null,
            [FromQuery] string? status = null,
            [FromQuery] string? sortBy = null,
            [FromQuery] string? sortOrder = "asc")
        {
            var query = _userManager.Users.AsQueryable();

            // Search by name, username, or email
            if (!string.IsNullOrWhiteSpace(search))
            {
                var searchLower = search.ToLower();
                query = query.Where(u => 
                    (u.UserName != null && u.UserName.ToLower().Contains(searchLower)) ||
                    (u.Email != null && u.Email.ToLower().Contains(searchLower)) ||
                    (u.PhoneNumber != null && u.PhoneNumber.Contains(search)));
            }

            // Filter by status
            if (!string.IsNullOrWhiteSpace(status))
            {
                var isActiveFilter = status.Equals("Active", StringComparison.OrdinalIgnoreCase);
                if (isActiveFilter)
                {
                    query = query.Where(u => !u.LockoutEnabled || (u.LockoutEnd == null || u.LockoutEnd <= DateTimeOffset.UtcNow));
                }
                else
                {
                    query = query.Where(u => u.LockoutEnabled && u.LockoutEnd != null && u.LockoutEnd > DateTimeOffset.UtcNow);
                }
            }

            // Apply sorting
            var isAscending = sortOrder?.ToLower() == "asc";
            switch (sortBy?.ToLower())
            {
                case "datecreated":
                    query = isAscending 
                        ? query.OrderBy(u => u.DateCreated)
                        : query.OrderByDescending(u => u.DateCreated);
                    break;
                case "name":
                default:
                    query = isAscending 
                        ? query.OrderBy(u => u.UserName ?? u.Email)
                        : query.OrderByDescending(u => u.UserName ?? u.Email);
                    break;
            }

            var users = await query.ToListAsync();

            var result = new List<object>();
            
            foreach (var user in users)
            {
                var roles = await _userManager.GetRolesAsync(user);
                var isActive = !user.LockoutEnabled || (user.LockoutEnd == null || user.LockoutEnd <= DateTimeOffset.UtcNow);
                
                result.Add(new
                {
                    id = user.Id,
                    email = user.Email,
                    userName = user.UserName,
                    phoneNumber = user.PhoneNumber,
                    country = user.Country,
                    dateCreated = user.DateCreated,
                    isActive = isActive,
                    role = roles.FirstOrDefault() ?? "User"
                });
            }

            return Ok(result);
        }
    }
}

