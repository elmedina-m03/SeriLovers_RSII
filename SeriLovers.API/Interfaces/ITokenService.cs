using SeriLovers.API.Models;

namespace SeriLovers.API.Interfaces
{
    public interface ITokenService
    {
        string GenerateToken(ApplicationUser user, IList<string> roles);
    }
}

