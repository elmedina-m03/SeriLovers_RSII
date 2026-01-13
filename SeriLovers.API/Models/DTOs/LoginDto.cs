using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class LoginDto
    {
        [Required(ErrorMessage = "Email or username is required.")]
        [StringLength(256, ErrorMessage = "Email or username cannot exceed 256 characters.")]
        [Display(Name = "Email or Username")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Password is required.")]
        [DataType(DataType.Password)]
        [Display(Name = "Password")]
        public string Password { get; set; } = string.Empty;

        [Display(Name = "Remember Me")]
        public bool RememberMe { get; set; } = false;

        [Display(Name = "Platform")]
        public string? Platform { get; set; } // "desktop" or "mobile"
    }
}

