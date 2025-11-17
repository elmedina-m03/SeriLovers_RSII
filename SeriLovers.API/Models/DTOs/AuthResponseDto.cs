using System.Collections.Generic;

namespace SeriLovers.API.Models.DTOs
{
    public class AuthResponseDto
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public string? Token { get; set; }
        public string? UserId { get; set; }
        public string? Email { get; set; }
        public List<string>? Errors { get; set; }
    }
}
