using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;

namespace SeriLovers.API.Models
{
    public class ApplicationUser : IdentityUser<int>
    {
        public string? Country { get; set; }
        public DateTime DateCreated { get; set; } = DateTime.UtcNow;

        public ICollection<Rating> Ratings { get; set; } = new List<Rating>();
        public ICollection<Watchlist> Watchlists { get; set; } = new List<Watchlist>();
        public ICollection<FavoriteCharacter> FavoriteCharacters { get; set; } = new List<FavoriteCharacter>();
        public ICollection<RecommendationLog> RecommendationLogs { get; set; } = new List<RecommendationLog>();
    }
}

