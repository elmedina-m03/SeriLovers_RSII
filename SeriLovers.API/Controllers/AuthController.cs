using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Events;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Linq;
using System.Threading.Tasks;
using System.Runtime.CompilerServices;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Handles user authentication, registration, and external identity integration.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("User Authentication")]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly SignInManager<ApplicationUser> _signInManager;
        private readonly ITokenService _tokenService;
        private readonly ILogger<AuthController> _logger;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly ApplicationDbContext _context;
        private readonly IMessageBusService _messageBusService;

        public AuthController(
            UserManager<ApplicationUser> userManager,
            SignInManager<ApplicationUser> signInManager,
            ITokenService tokenService,
            ILogger<AuthController> logger,
            IHttpClientFactory httpClientFactory,
            ApplicationDbContext context,
            IMessageBusService messageBusService)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _tokenService = tokenService;
            _logger = logger;
            _httpClientFactory = httpClientFactory;
            _context = context;
            _messageBusService = messageBusService;
        }

        /// <summary>
        /// Creates a default "Favorites" watchlist collection for a new user.
        /// </summary>
        private async Task EnsureDefaultFavoritesListAsync(int userId)
        {
            try
            {
                // Check if user already has a "Favorites" list (check both spellings)
                var favoritesExists = await _context.WatchlistCollections
                    .AnyAsync(c => c.UserId == userId && 
                                  (c.Name.ToLower() == "favorites" || c.Name.ToLower() == "favourite"));

                if (!favoritesExists)
                {
                    var favoritesList = new WatchlistCollection
                    {
                        Name = "Favorites",
                        Description = "Your favorite series",
                        UserId = userId,
                        CreatedAt = DateTime.UtcNow
                    };

                    _context.WatchlistCollections.Add(favoritesList);
                    await _context.SaveChangesAsync();
                    _logger.LogInformation("Created default 'Favorites' list for user {UserId}", userId);
                }
                else
                {
                    // Clean up any duplicate Favorites folders (shouldn't happen, but just in case)
                    var allFavorites = await _context.WatchlistCollections
                        .Where(c => c.UserId == userId && 
                                   (c.Name.ToLower() == "favorites" || c.Name.ToLower() == "favourite"))
                        .OrderBy(c => c.CreatedAt)
                        .ToListAsync();

                    if (allFavorites.Count > 1)
                    {
                        // Keep the first one (oldest)
                        var keepFavorites = allFavorites.First();
                        
                        // Move series from duplicates to the kept Favorites folder and delete duplicates
                        foreach (var duplicate in allFavorites.Skip(1))
                        {
                            var duplicateWatchlists = await _context.Watchlists
                                .Where(w => w.CollectionId == duplicate.Id)
                                .ToListAsync();
                            
                            foreach (var watchlist in duplicateWatchlists)
                            {
                                watchlist.CollectionId = keepFavorites.Id;
                            }
                            
                            _context.WatchlistCollections.Remove(duplicate);
                        }
                        
                        await _context.SaveChangesAsync();
                        _logger.LogInformation("Cleaned up {Count} duplicate Favorites folders for user {UserId}", 
                            allFavorites.Count - 1, userId);
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to create default Favorites list for user {UserId}", userId);
                // Don't throw - this is not critical for registration
            }
        }

        /// <summary>
        /// Performs Google OAuth login using an access token.
        /// </summary>
        /// <remarks>
        /// Sample request:
        /// 
        /// ```
        /// {
        ///   "accessToken": "ya29.a0AfH6SMB..."
        /// }
        /// ```
        /// 
        /// Sample response:
        /// 
        /// ```
        /// {
        ///   "success": true,
        ///   "message": "Google login successful",
        ///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        ///   "userId": "42",
        ///   "email": "user@example.com"
        /// }
        /// ```
        /// </remarks>
        [HttpPost("external/google")]
        [AllowAnonymous]
        [SwaggerOperation(
            Summary = "Google OAuth sign-in",
            Description = "Validates a Google OAuth 2.0 access token, creates a local user if necessary, and returns a JWT.")]
        public async Task<IActionResult> ExternalGoogleLogin([FromBody] GoogleLoginDto request)
        {
            if (!ModelState.IsValid || string.IsNullOrWhiteSpace(request.AccessToken))
            {
                return BadRequest(new AuthResponseDto
                {
                    Success = false,
                    Message = "Access token is required."
                });
            }

            var httpClient = _httpClientFactory.CreateClient();
            var httpRequest = new HttpRequestMessage(HttpMethod.Get, "https://www.googleapis.com/oauth2/v2/userinfo");
            httpRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", request.AccessToken);

            HttpResponseMessage userInfoResponse;
            try
            {
                userInfoResponse = await httpClient.SendAsync(httpRequest);
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "Error communicating with Google userinfo endpoint.");
                return StatusCode(StatusCodes.Status502BadGateway, new AuthResponseDto
                {
                    Success = false,
                    Message = "Unable to communicate with Google at this time."
                });
            }

            if (!userInfoResponse.IsSuccessStatusCode)
            {
                var errorBody = await userInfoResponse.Content.ReadAsStringAsync();
                _logger.LogWarning("Google userinfo request failed with status {StatusCode}: {Body}",
                    userInfoResponse.StatusCode, errorBody);

                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "Invalid Google access token."
                });
            }

            var content = await userInfoResponse.Content.ReadAsStringAsync();

            GoogleUserInfo? googleUser;
            try
            {
                googleUser = JsonSerializer.Deserialize<GoogleUserInfo>(content, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Failed to deserialize Google userinfo response: {Content}", content);
                return StatusCode(StatusCodes.Status502BadGateway, new AuthResponseDto
                {
                    Success = false,
                    Message = "Unable to parse user information from Google."
                });
            }

            if (googleUser == null || string.IsNullOrWhiteSpace(googleUser.Email))
            {
                _logger.LogWarning("Google userinfo response did not contain an email address. Payload: {Content}", content);
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "Unable to retrieve Google account information."
                });
            }

            var user = await _userManager.FindByEmailAsync(googleUser.Email);
            if (user == null)
            {
                user = new ApplicationUser
                {
                    UserName = googleUser.Email,
                    Email = googleUser.Email,
                    EmailConfirmed = true
                };

                var createResult = await _userManager.CreateAsync(user);
                if (!createResult.Succeeded)
                {
                    _logger.LogError("Failed to create local user for Google account {Email}: {Errors}",
                        googleUser.Email,
                        string.Join(", ", createResult.Errors.Select(e => e.Description)));

                    return StatusCode(StatusCodes.Status500InternalServerError, new AuthResponseDto
                    {
                        Success = false,
                        Message = "Failed to create local user account."
                    });
                }

                // Publish UserCreatedEvent for Google OAuth users (decoupled from main request flow)
                _ = Task.Run(async () =>
                {
                    try
                    {
                        var userCreatedEvent = new UserCreatedEvent
                        {
                            UserId = user.Id,
                            UserName = user.UserName ?? user.Email ?? "Unknown",
                            Email = user.Email ?? "Unknown",
                            CreatedAt = user.DateCreated
                        };
                        await _messageBusService.PublishEventAsync(userCreatedEvent);
                    }
                    catch (Exception ex)
                    {
                        // Log but don't fail the request
                        Console.WriteLine($"Error publishing UserCreatedEvent: {ex.Message}");
                    }
                });

                // Create default "Favorites" list for the new user
                await EnsureDefaultFavoritesListAsync(user.Id);
            }

            var loginInfo = new UserLoginInfo("Google", googleUser.Id ?? googleUser.Email, "Google");
            var userLogins = await _userManager.GetLoginsAsync(user);
            if (userLogins.All(l => l.LoginProvider != loginInfo.LoginProvider || l.ProviderKey != loginInfo.ProviderKey))
            {
                var addLoginResult = await _userManager.AddLoginAsync(user, loginInfo);
                if (!addLoginResult.Succeeded)
                {
                    _logger.LogWarning("Could not associate Google login with user {Email}: {Errors}",
                        user.Email,
                        string.Join(", ", addLoginResult.Errors.Select(e => e.Description)));
                }
            }

            if (!await _userManager.IsInRoleAsync(user, "User"))
            {
                var roleResult = await _userManager.AddToRoleAsync(user, "User");
                if (!roleResult.Succeeded)
                {
                    _logger.LogWarning("Failed to assign default role to Google user {Email}: {Errors}",
                        user.Email,
                        string.Join(", ", roleResult.Errors.Select(e => e.Description)));
                }
            }

            var roles = await _userManager.GetRolesAsync(user);
            var token = _tokenService.GenerateToken(user, roles);

            return Ok(new AuthResponseDto
            {
                Success = true,
                Message = "Google login successful",
                Token = token,
                UserId = user.Id.ToString(),
                Email = user.Email
            });
        }

        private class GoogleUserInfo
        {
            public string? Id { get; set; }
            public string? Email { get; set; }
            public string? Name { get; set; }
            public string? Given_Name { get; set; }
            public string? Family_Name { get; set; }
            public bool Verified_Email { get; set; }
            public string? Picture { get; set; }
        }

        /// <remarks>
        /// Sample request:
        /// 
        /// ```
        /// {
        ///   "email": "user@example.com",
        ///   "password": "P@ssw0rd!"
        /// }
        /// ```
        /// 
        /// Sample response:
        /// 
        /// ```
        /// {
        ///   "success": true,
        ///   "message": "User registered successfully",
        ///   "userId": "42",
        ///   "email": "user@example.com"
        /// }
        /// ```
        /// </remarks>
        [HttpPost("register")]
        [AllowAnonymous]
        [SwaggerOperation(
            Summary = "Register new user",
            Description = "Creates a new local user account with email and password credentials.")]
        public async Task<IActionResult> Register([FromBody] RegisterDto registerDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(new AuthResponseDto
                {
                    Success = false,
                    Message = "Invalid registration data",
                    Errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage).ToList()
                });
            }

            var user = new ApplicationUser
            {
                UserName = registerDto.Email,
                Email = registerDto.Email
            };

            var result = await _userManager.CreateAsync(user, registerDto.Password);

            if (result.Succeeded)
            {
                _logger.LogInformation("User created a new account with password.");

                // Create default "Favorites" list for the new user
                await EnsureDefaultFavoritesListAsync(user.Id);

                // Publish UserCreatedEvent (decoupled from main request flow)
                _ = Task.Run(async () =>
                {
                    try
                    {
                        var userCreatedEvent = new UserCreatedEvent
                        {
                            UserId = user.Id,
                            UserName = user.UserName ?? user.Email ?? "Unknown",
                            Email = user.Email ?? "Unknown",
                            CreatedAt = user.DateCreated
                        };
                        await _messageBusService.PublishEventAsync(userCreatedEvent);
                    }
                    catch (Exception ex)
                    {
                        // Log but don't fail the request
                        Console.WriteLine($"Error publishing UserCreatedEvent: {ex.Message}");
                    }
                });

                return Ok(new AuthResponseDto
                {
                    Success = true,
                    Message = "User registered successfully",
                    UserId = user.Id.ToString(),
                    Email = user.Email
                });
            }

            return BadRequest(new AuthResponseDto
            {
                Success = false,
                Message = "User registration failed",
                Errors = result.Errors.Select(e => e.Description).ToList()
            });
        }

        /// <remarks>
        /// Sample request:
        /// 
        /// ```
        /// {
        ///   "email": "user@example.com",
        ///   "password": "P@ssw0rd!",
        ///   "rememberMe": true
        /// }
        /// ```
        /// 
        /// Sample response:
        /// 
        /// ```
        /// {
        ///   "success": true,
        ///   "message": "Login successful",
        ///   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        ///   "userId": "42",
        ///   "email": "user@example.com"
        /// }
        /// ```
        /// </remarks>
        [HttpPost("login")]
        [AllowAnonymous]
        [SwaggerOperation(
            Summary = "Authenticate user",
            Description = "Validates credentials and issues a JWT for subsequent API requests.")]
        public async Task<IActionResult> Login([FromBody] LoginDto loginDto)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(new AuthResponseDto
                {
                    Success = false,
                    Message = "Invalid login data",
                    Errors = ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage).ToList()
                });
            }

            var user = await _userManager.FindByEmailAsync(loginDto.Email);

            if (user == null)
            {
                _logger.LogWarning("Login attempt failed: User not found for email {Email}", loginDto.Email);
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "Invalid login attempt"
                });
            }

            // Check if account is locked out
            if (await _userManager.IsLockedOutAsync(user))
            {
                _logger.LogWarning("User account locked out for email {Email}", loginDto.Email);
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "User account is locked out"
                });
            }

            // Verify password directly using CheckPasswordAsync
            var isPasswordValid = await _userManager.CheckPasswordAsync(user, loginDto.Password);

            if (!isPasswordValid)
            {
                // Increment access failed count for lockout tracking
                await _userManager.AccessFailedAsync(user);
                
                _logger.LogWarning("Invalid password attempt for email {Email}", loginDto.Email);
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "Invalid login attempt"
                });
            }

            // Password is valid - reset access failed count and proceed
            await _userManager.ResetAccessFailedCountAsync(user);

            // Check if user is allowed to sign in
            if (!await _signInManager.CanSignInAsync(user))
            {
                _logger.LogWarning("User is not allowed to sign in for email {Email}", loginDto.Email);
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "User is not allowed to sign in"
                });
            }

            _logger.LogInformation("User logged in successfully for email {Email}", loginDto.Email);

            // Get user roles
            var roles = await _userManager.GetRolesAsync(user);

            // Generate JWT token
            var token = _tokenService.GenerateToken(user, roles);

            return Ok(new AuthResponseDto
            {
                Success = true,
                Message = "Login successful",
                Token = token,
                UserId = user.Id.ToString(),
                Email = user.Email
            });
        }

        /// <summary>
        /// Updates the current user's profile
        /// </summary>
        [HttpPut("profile")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Update user profile",
            Description = "Updates the authenticated user's profile information including name, email, password, and avatar.")]
        public async Task<IActionResult> UpdateProfile([FromBody] ProfileUpdateDto updateDto)
        {
            // Convert DTO to dictionary for compatibility with existing logic
            var updateData = new Dictionary<string, object>();
            if (!string.IsNullOrWhiteSpace(updateDto.Name))
            {
                updateData["name"] = updateDto.Name;
            }
            if (!string.IsNullOrWhiteSpace(updateDto.Email))
            {
                updateData["email"] = updateDto.Email;
            }
            if (!string.IsNullOrWhiteSpace(updateDto.CurrentPassword) && !string.IsNullOrWhiteSpace(updateDto.NewPassword))
            {
                updateData["currentPassword"] = updateDto.CurrentPassword;
                updateData["newPassword"] = updateDto.NewPassword;
            }
            if (!string.IsNullOrWhiteSpace(updateDto.Avatar))
            {
                updateData["avatar"] = updateDto.Avatar;
            }
            if (!string.IsNullOrWhiteSpace(updateDto.AvatarUrl))
            {
                updateData["avatarUrl"] = updateDto.AvatarUrl;
            }

            _logger.LogInformation("UpdateProfile called. Name: {Name}, Email: {Email}", updateDto.Name, updateDto.Email);
            
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized(new { message = "User not found." });
            }

            _logger.LogInformation("Before update - UserId: {UserId}, Current Name: {Name}, Email: {Email}", 
                user.Id, user.Name, user.Email);

            if (!string.IsNullOrWhiteSpace(updateDto.Name))
            {
                _logger.LogInformation("Request to set Name to: {NewName}", updateDto.Name.Trim());
            }

            // Update password if provided
            if (!string.IsNullOrWhiteSpace(updateDto.CurrentPassword) && !string.IsNullOrWhiteSpace(updateDto.NewPassword))
            {
                var passwordValid = await _userManager.CheckPasswordAsync(user, updateDto.CurrentPassword!);
                if (!passwordValid)
                {
                    return BadRequest(new { message = "Current password is incorrect." });
                }

                var changePasswordResult = await _userManager.ChangePasswordAsync(user, updateDto.CurrentPassword!, updateDto.NewPassword!);
                if (!changePasswordResult.Succeeded)
                {
                    return BadRequest(new
                    {
                        message = "Failed to change password",
                        errors = changePasswordResult.Errors.Select(e => e.Description)
                    });
                }
            }

            // Get user from THIS context (not UserManager's context) to ensure proper tracking
            var userId = user.Id;
            var dbUser = await _context.Users.FindAsync(userId);
            if (dbUser == null)
            {
                return Unauthorized(new { message = "User not found in database." });
            }
            
            _logger.LogInformation("Found user in DbContext. Current Name: '{Name}'", dbUser.Name ?? "NULL");
            
            // Store the new values BEFORE updating entity (for SQL update)
            string? newName = null;
            string? newAvatarUrl = null;
            bool nameChanged = false;
            bool emailChanged = false;
            bool avatarChanged = false;
            
            if (!string.IsNullOrWhiteSpace(updateDto.Email))
            {
                dbUser.Email = updateDto.Email;
                dbUser.NormalizedEmail = updateDto.Email.ToUpperInvariant();
                dbUser.UserName = updateDto.Email;
                dbUser.NormalizedUserName = updateDto.Email.ToUpperInvariant();
                emailChanged = true;
            }
            
            if (!string.IsNullOrWhiteSpace(updateDto.Name))
            {
                newName = updateDto.Name.Trim();
                dbUser.Name = newName;
                nameChanged = true;
                _logger.LogInformation("Setting Name to: {Name}", newName);
            }
            
            if (!string.IsNullOrWhiteSpace(updateDto.Avatar))
            {
                newAvatarUrl = $"data:image/jpeg;base64,{updateDto.Avatar}";
                dbUser.AvatarUrl = newAvatarUrl;
                avatarChanged = true;
            }
            else if (!string.IsNullOrWhiteSpace(updateDto.AvatarUrl))
            {
                newAvatarUrl = updateDto.AvatarUrl;
                dbUser.AvatarUrl = newAvatarUrl;
                avatarChanged = true;
            }
            
            // Save Identity properties via UserManager first
            if (emailChanged)
            {
                var identityResult = await _userManager.UpdateAsync(dbUser);
                if (!identityResult.Succeeded)
                {
                    _logger.LogWarning("UserManager.UpdateAsync failed: {Errors}", 
                        string.Join(", ", identityResult.Errors.Select(e => e.Description)));
                }
            }
            
            // For custom properties (Name, AvatarUrl), use direct SQL update as EF Core tracking is unreliable
            if (nameChanged || avatarChanged)
            {
                try
                {
                    if (nameChanged && avatarChanged)
                    {
                        var sqlFormatted = FormattableStringFactory.Create(
                            $"UPDATE [AspNetUsers] SET [Name] = {{0}}, [AvatarUrl] = {{1}} WHERE [Id] = {{2}}",
                            newName ?? (object)DBNull.Value,
                            newAvatarUrl ?? (object)DBNull.Value,
                            userId);
                        _logger.LogInformation("Preparing SQL update for Name: '{Name}', AvatarUrl: '{AvatarUrl}'", newName, newAvatarUrl);
                        int rowsAffected = await _context.Database.ExecuteSqlInterpolatedAsync(sqlFormatted);
                        _logger.LogInformation("Direct SQL update completed. Rows affected: {Rows}, Name: '{Name}'", 
                            rowsAffected, newName ?? "NULL");
                    }
                    else if (nameChanged)
                    {
                        var sqlFormatted = FormattableStringFactory.Create(
                            $"UPDATE [AspNetUsers] SET [Name] = {{0}} WHERE [Id] = {{1}}",
                            newName ?? (object)DBNull.Value,
                            userId);
                        _logger.LogInformation("Preparing SQL update for Name: '{Name}', UserId: {UserId}", newName, userId);
                        int rowsAffected = await _context.Database.ExecuteSqlInterpolatedAsync(sqlFormatted);
                        _logger.LogInformation("Direct SQL update completed. Rows affected: {Rows}, Name: '{Name}'", 
                            rowsAffected, newName ?? "NULL");
                        
                        // Verify the update immediately by querying the database
                        var verifiedName = await _context.Users.AsNoTracking()
                            .Where(u => u.Id == userId)
                            .Select(u => u.Name)
                            .FirstOrDefaultAsync();
                        _logger.LogInformation("Verified Name in database after SQL update: '{Name}'", verifiedName ?? "NULL");
                    }
                    else if (avatarChanged)
                    {
                        var sqlFormatted = FormattableStringFactory.Create(
                            $"UPDATE [AspNetUsers] SET [AvatarUrl] = {{0}} WHERE [Id] = {{1}}",
                            newAvatarUrl ?? (object)DBNull.Value,
                            userId);
                        int rowsAffected = await _context.Database.ExecuteSqlInterpolatedAsync(sqlFormatted);
                        _logger.LogInformation("Direct SQL update completed. Rows affected: {Rows}, AvatarUrl: '{AvatarUrl}'", 
                            rowsAffected, newAvatarUrl ?? "NULL");
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to update custom properties via SQL. Falling back to EF Core.");
                    
                    // Fallback to EF Core
                    var entry = _context.Entry(dbUser);
                    if (nameChanged)
                    {
                        entry.Property(u => u.Name).IsModified = true;
                    }
                    if (avatarChanged)
                    {
                        entry.Property(u => u.AvatarUrl).IsModified = true;
                    }
                    await _context.SaveChangesAsync();
                }
            }
            
            // Reload user to get latest values after SQL update
            _context.Entry(dbUser).State = Microsoft.EntityFrameworkCore.EntityState.Detached;
            var verifyUser = await _context.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
            if (verifyUser != null)
            {
                dbUser = verifyUser;
                _logger.LogInformation("Reloaded user from database. UserId: {UserId}, Name: '{Name}', Email: {Email}", 
                    dbUser.Id, dbUser.Name ?? "NULL", dbUser.Email);
            }
            else
            {
                _logger.LogWarning("Could not reload user after update. UserId: {UserId}", userId);
            }
            
            // Use the reloaded entity to ensure we return the latest data
            user = dbUser;

            // Publish UserUpdatedEvent (decoupled from main request flow - fire-and-forget)
            if (user != null)
            {
                var userUpdatedEvent = new UserUpdatedEvent
                {
                    UserId = user.Id,
                    UserName = user.Name ?? user.UserName ?? user.Email ?? "Unknown",
                    Email = user.Email ?? "Unknown",
                    Country = user.Country,
                    AvatarUrl = user.AvatarUrl,
                    UpdatedAt = DateTime.UtcNow
                };
                // Fire-and-forget - won't block or throw exceptions
                _ = _messageBusService.PublishEventAsync(userUpdatedEvent);
            }
            if (user == null)
            {
                return Unauthorized(new { message = "User not found." });
            }

            // Get updated roles
            var roles = await _userManager.GetRolesAsync(user);

            // Generate new token with updated user info (including name and avatarUrl)
            var token = _tokenService.GenerateToken(user, roles);

            return Ok(new
            {
                success = true,
                message = "Profile updated successfully",
                token = token,
                user = new
                {
                    id = user.Id,
                    email = user.Email,
                    userName = user.UserName,
                    avatarUrl = user.AvatarUrl,
                    name = user.Name ?? "User"
                }
            });
        }
    }
}

