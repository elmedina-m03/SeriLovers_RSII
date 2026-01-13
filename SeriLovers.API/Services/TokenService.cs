using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;

namespace SeriLovers.API.Services
{
    public class TokenService : ITokenService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<TokenService> _logger;

        public TokenService(IConfiguration configuration, ILogger<TokenService> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        public string GenerateToken(ApplicationUser user, IList<string> roles)
        {
            _logger.LogInformation("Generating JWT for user {UserId} with roles {Roles}", user.Id, string.Join(",", roles));

            var jwtSettings = _configuration.GetSection("JwtSettings");
            var secretKey = jwtSettings["SecretKey"];
            var issuer = jwtSettings["Issuer"];
            var audience = jwtSettings["Audience"];
            var expirationMinutes = int.Parse(jwtSettings["ExpirationInMinutes"] ?? "60");

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey!));
            var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var claims = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
                new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                new Claim("userId", user.Id.ToString()) // Add userId claim for easier access
            };

            // Add avatar URL if available
            if (!string.IsNullOrEmpty(user.AvatarUrl))
            {
                claims.Add(new Claim("avatarUrl", user.AvatarUrl));
            }

            // Add name claim (use Name property if available, otherwise fallback)
            var displayName = user.Name ?? user.UserName ?? user.Email ?? "User";
            claims.Add(new Claim("name", displayName));

            // Add roles - add each role as a separate claim for ASP.NET Core compatibility
            // Also add roles as a JSON array string for easier parsing in Flutter
            foreach (var role in roles)
            {
                claims.Add(new Claim(ClaimTypes.Role, role)); // ASP.NET Core claim type
            }
            
            // Add roles as a JSON array string for Flutter to easily parse
            if (roles.Count > 0)
            {
                var rolesJson = System.Text.Json.JsonSerializer.Serialize(roles);
                claims.Add(new Claim("roles", rolesJson)); // JSON array of roles
                
                // Also add first role as "role" for backward compatibility
                claims.Add(new Claim("role", roles[0]));
            }

            var token = new JwtSecurityToken(
                issuer: issuer,
                audience: audience,
                claims: claims,
                expires: DateTime.UtcNow.AddMinutes(expirationMinutes),
                signingCredentials: credentials
            );

            var tokenString = new JwtSecurityTokenHandler().WriteToken(token);
            _logger.LogInformation("Generated JWT for user {UserId} expiring at {Expiration}", user.Id, token.ValidTo);
            return tokenString;
        }
    }
}

