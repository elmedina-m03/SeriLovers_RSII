using System;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class UserSeriesReminderDto
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int SeriesId { get; set; }
        public string? SeriesTitle { get; set; }
        public int LastEpisodeCount { get; set; }
        public DateTime EnabledAt { get; set; }
        public DateTime? LastCheckedAt { get; set; }
    }

    public class UserSeriesReminderCreateDto
    {
        [Required]
        public int SeriesId { get; set; }
    }
}

