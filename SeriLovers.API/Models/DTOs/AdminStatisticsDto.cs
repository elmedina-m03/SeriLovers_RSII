using System.Collections.Generic;

namespace SeriLovers.API.Models.DTOs
{
    /// <summary>
    /// DTO for admin statistics response
    /// </summary>
    public class AdminStatisticsDto
    {
        public TotalsDto Totals { get; set; } = new TotalsDto();
        public List<GenreDistributionDto> GenreDistribution { get; set; } = new List<GenreDistributionDto>();
        public List<MonthlyWatchingDto> MonthlyWatching { get; set; } = new List<MonthlyWatchingDto>();
        public List<TopSeriesDto> TopSeries { get; set; } = new List<TopSeriesDto>();
    }

    /// <summary>
    /// DTO for totals statistics
    /// </summary>
    public class TotalsDto
    {
        public int Users { get; set; }
        public int Series { get; set; }
        public int Actors { get; set; }
        public int WatchlistItems { get; set; }
    }

    /// <summary>
    /// DTO for genre distribution statistics
    /// </summary>
    public class GenreDistributionDto
    {
        public string Genre { get; set; } = string.Empty;
        public double Percentage { get; set; }
    }

    /// <summary>
    /// DTO for monthly watching statistics
    /// </summary>
    public class MonthlyWatchingDto
    {
        public string Month { get; set; } = string.Empty; // Format: "YYYY-MM"
        public int Views { get; set; }
    }

    /// <summary>
    /// DTO for top rated series statistics
    /// </summary>
    public class TopSeriesDto
    {
        public int Id { get; set; }
        public string Title { get; set; } = string.Empty;
        public double AvgRating { get; set; }
        public int Views { get; set; } // Total views = ratings count + watchlist count
        public string? ImageUrl { get; set; } // Series poster/cover image
    }
}
