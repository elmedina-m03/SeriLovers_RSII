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
                // Show all users in total count (no filtering)
                var totalUsers = await _context.Users
                    .AsNoTracking()
                    .CountAsync();
                
                var totalSeries = await _context.Series.CountAsync();
                var totalActors = await _context.Actors.CountAsync();
                
                // Count ALL watchlist items (including test users like mobile/desktop for seminar testing)
                var totalWatchlistItems = await _context.Watchlists
                    .CountAsync();

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
                // Filter out test users to match reviews page (only real user activity)
                if (totalSeries > 0)
                {
                    // Materialize ratings and watchlists first, then filter test users in memory
                    // EF Core cannot translate EndsWith with StringComparison to SQL
                    var allRatings = await _context.Ratings
                        .Include(r => r.User)
                        .ToListAsync();
                    
                    var allWatchlists = await _context.Watchlists
                        .Include(w => w.User)
                        .ToListAsync();
                    
                    // Include ALL ratings and watchlists (including test users like mobile/desktop for seminar testing)
                    // Filter only excludes testuser1-4, but includes mobile and desktop users
                    var realRatings = allRatings
                        .Where(r => r.User != null
                            && (
                                // Include mobile and desktop users (seminar test users) - check username first
                                (r.User.UserName != null && (r.User.UserName.Equals("mobile", StringComparison.OrdinalIgnoreCase) 
                                    || r.User.UserName.Equals("desktop", StringComparison.OrdinalIgnoreCase)))
                                ||
                                // Include other users that don't match test patterns
                                (r.User.Email != null
                                    && !r.User.Email.EndsWith("@test.com", StringComparison.OrdinalIgnoreCase)
                                    && !r.User.Email.EndsWith("@example.com", StringComparison.OrdinalIgnoreCase)
                                    && !r.User.Email.EndsWith("@test", StringComparison.OrdinalIgnoreCase)
                                    && !r.User.Email.StartsWith("testuser", StringComparison.OrdinalIgnoreCase))
                            ))
                        .ToList();
                    
                    var realWatchlists = allWatchlists
                        .Where(w => w.User != null
                            && (
                                // Include mobile and desktop users (seminar test users) - check username first
                                (w.User.UserName != null && (w.User.UserName.Equals("mobile", StringComparison.OrdinalIgnoreCase) 
                                    || w.User.UserName.Equals("desktop", StringComparison.OrdinalIgnoreCase)))
                                ||
                                // Include other users that don't match test patterns
                                (w.User.Email != null
                                    && !w.User.Email.EndsWith("@test.com", StringComparison.OrdinalIgnoreCase)
                                    && !w.User.Email.EndsWith("@example.com", StringComparison.OrdinalIgnoreCase)
                                    && !w.User.Email.EndsWith("@test", StringComparison.OrdinalIgnoreCase)
                                    && !w.User.Email.StartsWith("testuser", StringComparison.OrdinalIgnoreCase))
                            ))
                        .ToList();
                    
                    // Group by series and calculate views (real ratings + real watchlists)
                    var seriesViews = realRatings
                        .GroupBy(r => r.SeriesId)
                        .ToDictionary(g => g.Key, g => g.Count());
                    
                    var seriesWatchlistCounts = realWatchlists
                        .GroupBy(w => w.SeriesId)
                        .ToDictionary(g => g.Key, g => g.Count());
                    
                    // Get all series IDs that have ratings or watchlists (materialize to avoid EF Core translation issues)
                    var seriesIdsWithActivity = seriesViews.Keys
                        .Union(seriesWatchlistCounts.Keys)
                        .Distinct()
                        .ToList();
                    
                    if (seriesIdsWithActivity.Any())
                    {
                        // Calculate average ratings for each series from ALL ratings in database
                        // This ensures we show correct ratings from all users, not just filtered ones
                        // Use direct query to Ratings table to ensure we get all ratings
                        var seriesRatingsFromDb = await _context.Ratings
                            .Where(r => seriesIdsWithActivity.Contains(r.SeriesId))
                            .GroupBy(r => r.SeriesId)
                            .Select(g => new
                            {
                                SeriesId = g.Key,
                                // Calculate average from ALL ratings in database for this series
                                // This includes ratings from all users (mobile, desktop, test users, etc.)
                                AvgRating = g.Average(r => r.Score)
                            })
                            .ToListAsync();
                        
                        var seriesRatingsDict = seriesRatingsFromDb
                            .ToDictionary(s => s.SeriesId, s => s.AvgRating);
                        
                        _logger.LogDebug("Calculated average ratings for {Count} series from database", seriesRatingsDict.Count);
                        foreach (var kvp in seriesRatingsDict.Take(5))
                        {
                            _logger.LogDebug("Series {SeriesId}: AvgRating = {AvgRating}", kvp.Key, kvp.Value);
                        }
                        
                        // Get all series and calculate TopSeries with real data
                        var allSeries = await _context.Series
                            .Where(s => seriesIdsWithActivity.Contains(s.Id))
                            .ToListAsync();
                        
                        result.TopSeries = allSeries
                            .Select(s => new TopSeriesDto
                            {
                                Id = s.Id,
                                Title = s.Title ?? "Unknown",
                                // Use average from ALL ratings in database for this series
                                AvgRating = seriesRatingsDict.ContainsKey(s.Id) ? seriesRatingsDict[s.Id] : 0.0,
                                Views = (seriesViews.ContainsKey(s.Id) ? seriesViews[s.Id] : 0) + 
                                        (seriesWatchlistCounts.ContainsKey(s.Id) ? seriesWatchlistCounts[s.Id] : 0),
                                ImageUrl = s.ImageUrl
                            })
                            .OrderByDescending(s => s.AvgRating)
                            .ThenByDescending(s => s.Views)
                            .Take(5)
                            .ToList();
                        
                        _logger.LogDebug("Top series calculated: {Count} series with ratings", result.TopSeries.Count);
                        foreach (var topSeries in result.TopSeries)
                        {
                            _logger.LogDebug("Top Series: {Title} - AvgRating: {AvgRating}, Views: {Views}", 
                                topSeries.Title, topSeries.AvgRating, topSeries.Views);
                        }
                    }
                    else
                    {
                        result.TopSeries = new List<TopSeriesDto>();
                    }
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

