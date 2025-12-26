using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    /// <summary>
    /// DTO for updating user profile information
    /// </summary>
    public class ProfileUpdateDto
    {
        /// <summary>
        /// User's display name
        /// </summary>
        [StringLength(256)]
        public string? Name { get; set; }

        /// <summary>
        /// User's email address
        /// </summary>
        [EmailAddress]
        [StringLength(256)]
        public string? Email { get; set; }

        /// <summary>
        /// Current password (required when changing password)
        /// </summary>
        [DataType(DataType.Password)]
        public string? CurrentPassword { get; set; }

        /// <summary>
        /// New password (required when changing password)
        /// </summary>
        [DataType(DataType.Password)]
        [StringLength(100, MinimumLength = 8)]
        public string? NewPassword { get; set; }

        /// <summary>
        /// Avatar image as base64 string
        /// </summary>
        public string? Avatar { get; set; }

        /// <summary>
        /// Avatar URL (if already uploaded)
        /// </summary>
        [StringLength(500)]
        public string? AvatarUrl { get; set; }
    }
}

