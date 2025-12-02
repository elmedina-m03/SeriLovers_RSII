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

            // Add name claim (extract from UserName or email if no custom name)
            var displayName = user.UserName ?? user.Email ?? "User";
            // If UserName looks like an email, extract the name part
            if (displayName.Contains('@'))
            {
                var emailPart = displayName.Split('@')[0];
                displayName = emailPart[0].ToString().ToUpper() + emailPart.Substring(1);
            }
            claims.Add(new Claim("name", displayName));

            // Add roles using both standard JWT claim name and ASP.NET Core claim type
            foreach (var role in roles)
            {
                claims.Add(new Claim("role", role)); // Standard JWT claim name
                claims.Add(new Claim(ClaimTypes.Role, role)); // ASP.NET Core claim type
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

