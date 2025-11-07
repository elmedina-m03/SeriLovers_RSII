using Microsoft.AspNetCore.Identity;

namespace SeriLovers.API.Models
{
    public class ApplicationUser : IdentityUser<int>
    {
        // You can add custom properties here if needed
        // Example:
        // public string FirstName { get; set; } = string.Empty;
        // public string LastName { get; set; } = string.Empty;
    }
}

