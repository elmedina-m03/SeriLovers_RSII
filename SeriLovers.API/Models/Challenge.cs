using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    /// <summary>
    /// Challenge model representing user challenges in the system
    /// </summary>
    public class Challenge
    {
        public int Id { get; set; }

        [Required]
        [StringLength(200, ErrorMessage = "Name cannot exceed 200 characters.")]
        public string Name { get; set; } = string.Empty;

        [StringLength(2000, ErrorMessage = "Description cannot exceed 2000 characters.")]
        public string? Description { get; set; }

        [Required]
        public ChallengeDifficulty Difficulty { get; set; }

        [Required]
        [Range(1, int.MaxValue, ErrorMessage = "TargetCount must be at least 1.")]
        public int TargetCount { get; set; }

        public int ParticipantsCount { get; set; } = 0;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}

