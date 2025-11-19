using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Linq;
using System.Threading.Tasks;
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

        public AuthController(
            UserManager<ApplicationUser> userManager,
            SignInManager<ApplicationUser> signInManager,
            ITokenService tokenService,
            ILogger<AuthController> logger,
            IHttpClientFactory httpClientFactory)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _tokenService = tokenService;
            _logger = logger;
            _httpClientFactory = httpClientFactory;
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
    }
}

