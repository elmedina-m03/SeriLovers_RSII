using Microsoft.AspNetCore.Identity;
using System.Collections.Generic;

namespace SeriLovers.API.Models
{
    public class ApplicationUser : IdentityUser<int>
    {
        public ICollection<Rating> Ratings { get; set; } = new List<Rating>();
        public ICollection<Watchlist> Watchlists { get; set; } = new List<Watchlist>();
    }
}

