using System;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace SeriLovers.API.Security
{
    public class BasicAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        private readonly IConfiguration _configuration;

        public BasicAuthHandler(
            IOptionsMonitor<AuthenticationSchemeOptions> options,
            ILoggerFactory logger,
            System.Text.Encodings.Web.UrlEncoder encoder,
            IConfiguration configuration)
            : base(options, logger, encoder)
        {
            _configuration = configuration;
        }

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            if (!Request.Headers.TryGetValue("Authorization", out var authorizationHeader))
            {
                return Task.FromResult(AuthenticateResult.NoResult());
            }

            if (!authorizationHeader.ToString().StartsWith("Basic ", StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(AuthenticateResult.NoResult());
            }

            var token = authorizationHeader.ToString().Substring("Basic ".Length).Trim();

            string credentials;
            try
            {
                var credentialBytes = Convert.FromBase64String(token);
                credentials = Encoding.UTF8.GetString(credentialBytes);
            }
            catch (FormatException)
            {
                return Task.FromResult(AuthenticateResult.Fail("Invalid Authorization header."));
            }

            var parts = credentials.Split(':', 2);
            if (parts.Length != 2)
            {
                return Task.FromResult(AuthenticateResult.Fail("Invalid Authorization header."));
            }

            var username = parts[0];
            var password = parts[1];

            var expectedUsername = _configuration["BasicAuth:Username"];
            var expectedPassword = _configuration["BasicAuth:Password"];

            if (string.IsNullOrEmpty(expectedUsername) || string.IsNullOrEmpty(expectedPassword))
            {
                return Task.FromResult(AuthenticateResult.Fail("Basic authentication is not configured."));
            }

            if (!string.Equals(username, expectedUsername, StringComparison.Ordinal) ||
                !string.Equals(password, expectedPassword, StringComparison.Ordinal))
            {
                return Task.FromResult(AuthenticateResult.Fail("Invalid username or password."));
            }

            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, username),
                new Claim(ClaimTypes.Name, username)
            };

            var identity = new ClaimsIdentity(claims, Scheme.Name);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, Scheme.Name);

            return Task.FromResult(AuthenticateResult.Success(ticket));
        }

        protected override Task HandleChallengeAsync(AuthenticationProperties properties)
        {
            Response.Headers["WWW-Authenticate"] = "Basic";
            return base.HandleChallengeAsync(properties);
        }
    }
}
