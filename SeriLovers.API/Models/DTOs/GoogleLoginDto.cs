using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class GoogleLoginDto
    {
        [Required]
        public string AccessToken { get; set; } = string.Empty;
    }
}
