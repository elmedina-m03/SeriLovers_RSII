using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Services
{
    /// <summary>
    /// Service for computing admin statistics
    /// </summary>
    public class AdminStatisticsService : IAdminStatisticsService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<AdminStatisticsService> _logger;

        public AdminStatisticsService(ApplicationDbContext context, ILogger<AdminStatisticsService> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Gets comprehensive admin statistics
        /// </summary>
        public async Task<AdminStatisticsDto> GetStatisticsAsync()
        {
            _logger.LogInformation("Computing admin statistics");

            var result = new AdminStatisticsDto();

            try
            {
                // Count totals - efficient queries with fallback for empty database
                var totalUsers = await _context.Users.CountAsync();
                var totalSeries = await _context.Series.CountAsync();
                var totalActors = await _context.Actors.CountAsync();
                var totalWatchlistItems = await _context.Watchlists.CountAsync();

                result.Totals = new TotalsDto
                {
                    Users = totalUsers,
                    Series = totalSeries,
                    Actors = totalActors,
                    WatchlistItems = totalWatchlistItems
                };

                _logger.LogDebug("Totals: Users={Users}, Series={Series}, Actors={Actors}, Watchlists={Watchlists}",
                    totalUsers, totalSeries, totalActors, totalWatchlistItems);

                // Top rated series - top 5 by average rating with views (ratings + watchlist count)
                if (totalSeries > 0)
                {
                    result.TopSeries = await _context.Series
                        .Where(s => s.Ratings.Any() || s.Watchlists.Any())
                        .Select(s => new TopSeriesDto
                        {
                            Id = s.Id,
                            Title = s.Title ?? "Unknown",
                            AvgRating = s.Ratings.Any() ? s.Ratings.Average(r => r.Score) : 0.0,
                            Views = s.Ratings.Count() + s.Watchlists.Count()
                        })
                        .OrderByDescending(s => s.AvgRating)
                        .ThenByDescending(s => s.Views)
                        .Take(5)
                        .ToListAsync();
                }
                // Fallback: empty list if no series

                _logger.LogDebug("Top series count: {Count}", result.TopSeries.Count);

                // Genre distribution - calculate percentage based on series count per genre
                if (totalSeries > 0)
                {
                    var genreGroups = await _context.SeriesGenres
                        .Where(sg => sg.Genre != null && !string.IsNullOrEmpty(sg.Genre.Name))
                        .GroupBy(sg => sg.Genre!.Name)
                        .Select(g => new
                        {
                            Genre = g.Key ?? "Unknown",
                            Count = g.Count()
                        })
                        .OrderByDescending(g => g.Count)
                        .ToListAsync();

                    result.GenreDistribution = genreGroups
                        .Select(g => new GenreDistributionDto
                        {
                            Genre = g.Genre,
                            Percentage = Math.Round((g.Count * 100.0) / totalSeries, 2)
                        })
                        .ToList();
                }
                // Fallback: empty list if no series

                _logger.LogDebug("Genre distribution count: {Count}", result.GenreDistribution.Count);

                // Monthly watching - last 12 months
                // Combine ratings and watchlists for views count
                var twelveMonthsAgo = DateTime.UtcNow.AddMonths(-12);
                
                // Get monthly data from ratings
                var monthlyRatings = await _context.Ratings
                    .Where(r => r.CreatedAt >= twelveMonthsAgo)
                    .GroupBy(r => new { r.CreatedAt.Year, r.CreatedAt.Month })
                    .Select(g => new
                    {
                        Year = g.Key.Year,
                        Month = g.Key.Month,
                        Count = g.Count()
                    })
                    .ToListAsync();

                // Get monthly data from watchlists
                var monthlyWatchlists = await _context.Watchlists
                    .Where(w => w.AddedAt >= twelveMonthsAgo)
                    .GroupBy(w => new { w.AddedAt.Year, w.AddedAt.Month })
                    .Select(g => new
                    {
                        Year = g.Key.Year,
                        Month = g.Key.Month,
                        Count = g.Count()
                    })
                    .ToListAsync();

                // Combine and aggregate monthly data
                var monthlyData = monthlyRatings
                    .Concat(monthlyWatchlists)
                    .GroupBy(m => new { m.Year, m.Month })
                    .Select(g => new
                    {
                        Year = g.Key.Year,
                        Month = g.Key.Month,
                        Views = g.Sum(m => m.Count)
                    })
                    .OrderBy(m => m.Year)
                    .ThenBy(m => m.Month)
                    .Take(12)
                    .ToList();

                result.MonthlyWatching = monthlyData
                    .Select(m => new MonthlyWatchingDto
                    {
                        Month = $"{m.Year}-{m.Month:D2}", // Format as "YYYY-MM"
                        Views = m.Views
                    })
                    .ToList();

                // Fallback: empty list if no data (already handled by empty query result)

                _logger.LogDebug("Monthly watching count: {Count}", result.MonthlyWatching.Count);
                _logger.LogInformation("Admin statistics computed successfully");

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error computing admin statistics");
                // Return empty result on error (graceful fallback)
                return new AdminStatisticsDto
                {
                    Totals = new TotalsDto(),
                    GenreDistribution = new List<GenreDistributionDto>(),
                    MonthlyWatching = new List<MonthlyWatchingDto>(),
                    TopSeries = new List<TopSeriesDto>()
                };
            }
        }
    }
}

