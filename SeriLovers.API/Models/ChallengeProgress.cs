using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models
{
    /// <summary>
    /// Challenge progress model tracking user progress on challenges
    /// </summary>
    public class ChallengeProgress
    {
        public int Id { get; set; }

        [Required]
        public int ChallengeId { get; set; }

        [Required]
        public int UserId { get; set; }

        [Required]
        [Range(0, int.MaxValue)]
        public int ProgressCount { get; set; } = 0;

        [Required]
        public ChallengeProgressStatus Status { get; set; } = ChallengeProgressStatus.InProgress;

        public DateTime? CompletedAt { get; set; }

        // Navigation properties
        public Challenge? Challenge { get; set; }
        public ApplicationUser? User { get; set; }
    }

    /// <summary>
    /// Status of challenge progress
    /// </summary>
    public enum ChallengeProgressStatus
    {
        InProgress = 0,
        Completed = 1,
        Abandoned = 2
    }
}

