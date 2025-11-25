using SeriLovers.API.Models;

namespace SeriLovers.API.Models.DTOs
{
    /// <summary>
    /// DTO for Challenge response
    /// </summary>
    public class ChallengeDto
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public ChallengeDifficulty Difficulty { get; set; }
        public int TargetCount { get; set; }
        public int ParticipantsCount { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    /// <summary>
    /// DTO for creating a new challenge
    /// </summary>
    public class ChallengeCreateDto
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public ChallengeDifficulty Difficulty { get; set; }
        public int TargetCount { get; set; }
    }

    /// <summary>
    /// DTO for updating an existing challenge
    /// </summary>
    public class ChallengeUpdateDto
    {
        public string Name { get; set; } = string.Empty;
        public string? Description { get; set; }
        public ChallengeDifficulty Difficulty { get; set; }
        public int TargetCount { get; set; }
    }
}

