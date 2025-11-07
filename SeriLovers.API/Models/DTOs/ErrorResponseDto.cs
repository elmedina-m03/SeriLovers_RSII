namespace SeriLovers.API.Models.DTOs
{
    public class ErrorResponseDto
    {
        public string Message { get; set; } = string.Empty;
        public string? Details { get; set; }
        public int StatusCode { get; set; }
        public List<string>? Errors { get; set; }
        public string? TraceId { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    }
}

