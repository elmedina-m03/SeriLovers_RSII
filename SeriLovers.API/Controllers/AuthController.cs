using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly SignInManager<ApplicationUser> _signInManager;
        private readonly ITokenService _tokenService;
        private readonly ILogger<AuthController> _logger;

        public AuthController(
            UserManager<ApplicationUser> userManager,
            SignInManager<ApplicationUser> signInManager,
            ITokenService tokenService,
            ILogger<AuthController> logger)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _tokenService = tokenService;
            _logger = logger;
        }

        [HttpPost("register")]
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

        [HttpPost("login")]
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
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "Invalid login attempt"
                });
            }

            var result = await _signInManager.PasswordSignInAsync(
                user.UserName!,
                loginDto.Password,
                loginDto.RememberMe,
                lockoutOnFailure: true);

            if (result.Succeeded)
            {
                _logger.LogInformation("User logged in.");

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

            if (result.IsLockedOut)
            {
                _logger.LogWarning("User account locked out.");
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "User account is locked out"
                });
            }

            if (result.IsNotAllowed)
            {
                return Unauthorized(new AuthResponseDto
                {
                    Success = false,
                    Message = "User is not allowed to sign in"
                });
            }

            return Unauthorized(new AuthResponseDto
            {
                Success = false,
                Message = "Invalid login attempt"
            });
        }
    }
}

