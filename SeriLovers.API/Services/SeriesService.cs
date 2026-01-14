using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Services
{
    public class SeriesService : ISeriesService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<SeriesService> _logger;

        public SeriesService(ApplicationDbContext context, ILogger<SeriesService> logger)
        {
            _context = context;
            _logger = logger;
        }

        private IQueryable<Series> QuerySeriesWithRelationships(bool includeFeedback = false)
        {
            var query = _context.Series
                                .AsNoTracking()
                                .AsSplitQuery()
                                .Include(s => s.Seasons)
                                    .ThenInclude(season => season.Episodes)
                                .Include(s => s.SeriesGenres)
                                    .ThenInclude(sg => sg.Genre)
                                .Include(s => s.SeriesActors)
                                    .ThenInclude(sa => sa.Actor)
                                .AsQueryable();

            if (includeFeedback)
            {
                query = query
                    .Include(s => s.Ratings)
                        .ThenInclude(r => r.User)
                    .Include(s => s.Watchlists);
            }

            return query;
        }

        public async Task<PagedResult<Series>> GetAllAsync(int page = 1, int pageSize = 10, int? genreId = null, double? minRating = null, string? search = null, int? year = null, string? sortBy = null, string? sortOrder = null)
        {
            _logger.LogDebug("Retrieving paged series list. Page: {Page}, PageSize: {PageSize}, GenreId: {GenreId}, MinRating: {MinRating}, Search: {Search}, Year: {Year}", page, pageSize, genreId, minRating, search, year);

            page = page <= 0 ? 1 : page;
            pageSize = pageSize <= 0 ? 10 : pageSize;

            // Start with base query - we'll add includes later for the final fetch
            var baseQuery = _context.Series.AsQueryable();

            // Apply search filter (title and actor names only - precise search)
            if (!string.IsNullOrWhiteSpace(search))
            {
                var keyword = search.Trim().ToLower();

                // Search only in title and actor names (FirstName, LastName, FullName)
                // Description is excluded to avoid too broad matches
                // Use explicit join through SeriesActors to Actors for proper SQL generation
                baseQuery = baseQuery.Where(s =>
                    s.Title.ToLower().Contains(keyword) ||
                    _context.SeriesActors
                        .Where(sa => sa.SeriesId == s.Id)
                        .Any(sa => _context.Actors
                            .Any(a => a.Id == sa.ActorId &&
                                (a.FirstName.ToLower().Contains(keyword) ||
                                 a.LastName.ToLower().Contains(keyword) ||
                                 (a.FirstName + " " + a.LastName).ToLower().Contains(keyword)))));
            }

            // Apply genre filter
            if (genreId.HasValue)
            {
                baseQuery = baseQuery.Where(s =>
                    _context.SeriesGenres
                        .Any(sg => sg.SeriesId == s.Id && sg.GenreId == genreId.Value));
            }

            // Apply rating filter
            if (minRating.HasValue)
            {
                baseQuery = baseQuery.Where(s => s.Rating >= minRating.Value);
            }

            // Apply year filter
            if (year.HasValue)
            {
                baseQuery = baseQuery.Where(s => s.ReleaseDate.Year == year.Value);
            }

            // Get total count before pagination
            var totalItems = baseQuery.Count();
            var totalPages = totalItems == 0 ? 0 : (int)Math.Ceiling(totalItems / (double)pageSize);

            IOrderedQueryable<Series> orderedQuery;
            var isAscending = string.IsNullOrEmpty(sortOrder) || sortOrder.ToLower() == "asc";
            
            switch (sortBy?.ToLower())
            {
                case "year":
                    orderedQuery = isAscending 
                        ? baseQuery.OrderBy(s => s.ReleaseDate.Year)
                        : baseQuery.OrderByDescending(s => s.ReleaseDate.Year);
                    break;
                case "rating":
                    orderedQuery = isAscending 
                        ? baseQuery.OrderBy(s => s.Rating)
                        : baseQuery.OrderByDescending(s => s.Rating);
                    break;
                case "title":
                default:
                    orderedQuery = isAscending 
                        ? baseQuery.OrderBy(s => s.Title)
                        : baseQuery.OrderByDescending(s => s.Title);
                    break;
            }

            var seriesIds = orderedQuery
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(s => s.Id)
                .ToList();

            var items = QuerySeriesWithRelationships()
                .Where(s => seriesIds.Contains(s.Id))
                .ToList();

            var itemsDict = items.ToDictionary(s => s.Id);
            items = seriesIds
                .Where(id => itemsDict.ContainsKey(id))
                .Select(id => itemsDict[id])
                .ToList();

            foreach (var series in items)
            {
                HydrateSeries(series);
            }

            await PopulateFeedbackCountsAsync(items);

            return new PagedResult<Series>
            {
                Items = items,
                TotalItems = totalItems,
                TotalPages = totalPages,
                CurrentPage = page,
                PageSize = pageSize
            };
        }

        // Keep synchronous version for backward compatibility
        public PagedResult<Series> GetAll(int page = 1, int pageSize = 10, int? genreId = null, double? minRating = null, string? search = null, int? year = null, string? sortBy = null, string? sortOrder = null)
        {
            return GetAllAsync(page, pageSize, genreId, minRating, search, year, sortBy, sortOrder).GetAwaiter().GetResult();
        }

        public async Task<Series?> GetByIdAsync(int id)
        {
            _logger.LogDebug("Fetching series with id {SeriesId}", id);
            var series = QuerySeriesWithRelationships(includeFeedback: true)
                .FirstOrDefault(s => s.Id == id);

            if (series != null)
            {
                HydrateSeries(series);
                
                // Filter ratings - include mobile and desktop users (seminar test users), exclude other test users
                var realRatings = series.Ratings?
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
                    .ToList() ?? new List<Rating>();
                
                var realWatchlists = series.Watchlists?
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
                    .ToList() ?? new List<Watchlist>();
                
                series.RatingsCount = realRatings.Count;
                series.WatchlistsCount = realWatchlists.Count;
                
                // CRITICAL: Always use Series.Rating from database (already calculated and updated by PopulateFeedbackCountsAsync)
                // If ratings exist, ensure Series.Rating matches the calculated average
                // If no ratings, Series.Rating contains the manually entered fallback value
                if (realRatings.Any())
                {
                    var averageRating = Math.Round(realRatings.Average(r => r.Score), 2);
                    
                    // Update in-memory object for current response
                    series.Rating = averageRating;
                    
                    // Update in database if different (ensures consistency)
                    if (Math.Abs(series.Rating - averageRating) > 0.01)
                    {
                        _logger.LogDebug("Updating Series {SeriesId} rating from {OldRating} to {NewRating} based on {Count} user ratings",
                            series.Id, series.Rating, averageRating, realRatings.Count);
                        
                        var seriesInDb = await _context.Series.FindAsync(id);
                        if (seriesInDb != null)
                        {
                            seriesInDb.Rating = averageRating;
                            await _context.SaveChangesAsync();
                            _logger.LogInformation("Updated Series {SeriesId} rating in database from {OldRating} to {NewRating}",
                                id, series.Rating, averageRating);
                        }
                    }
                }
                // If no ratings, series.Rating already contains the manually entered fallback value - use it as-is
            }

            return series;
        }

        // Keep synchronous version for backward compatibility (but it won't update database)
        public Series? GetById(int id)
        {
            return GetByIdAsync(id).GetAwaiter().GetResult();
        }

        public async Task<List<Series>> SearchAsync(string keyword)
        {
            if (string.IsNullOrWhiteSpace(keyword))
            {
                _logger.LogDebug("Search keyword empty; returning all series.");
                var allSeries = QuerySeriesWithRelationships()
                    .OrderBy(s => s.Title)
                    .ToList();

                foreach (var series in allSeries)
                {
                    HydrateSeries(series);
                }

                await PopulateFeedbackCountsAsync(allSeries);

                return allSeries;
            }

            _logger.LogDebug("Searching series with keyword {Keyword}", keyword);
            var lowerKeyword = keyword.ToLower();

            // Search only in title and actor names (exclude description for precise results)
            var results = QuerySeriesWithRelationships()
                .Where(s => s.Title.ToLower().Contains(lowerKeyword) ||
                    s.SeriesActors.Any(sa => 
                        sa.Actor.FirstName.ToLower().Contains(lowerKeyword) ||
                        sa.Actor.LastName.ToLower().Contains(lowerKeyword) ||
                        (sa.Actor.FirstName + " " + sa.Actor.LastName).ToLower().Contains(lowerKeyword)))
                .OrderBy(s => s.Title)
                .ToList();

            foreach (var series in results)
            {
                HydrateSeries(series);
            }

            await PopulateFeedbackCountsAsync(results);

            return results;
        }
        
        // Keep synchronous version for backward compatibility
        public List<Series> Search(string keyword)
        {
            return SearchAsync(keyword).GetAwaiter().GetResult();
        }

        public void Add(Series series)
        {
            if (series == null)
                throw new ArgumentNullException(nameof(series));

            _logger.LogInformation("Creating series {Title}", series.Title);

            if (string.IsNullOrWhiteSpace(series.Title))
                throw new ArgumentException("Series title cannot be empty.", nameof(series));

            var incomingGenreIds = ExtractGenreIds(series);
            var incomingActorLinks = ExtractActorLinks(series);

            series.SeriesGenres = new List<SeriesGenre>();
            series.SeriesActors = new List<SeriesActor>();

            _context.Series.Add(series);
            _context.SaveChanges();

            if (incomingGenreIds.Count > 0)
            {
                foreach (var genreId in incomingGenreIds)
                {
                    _context.SeriesGenres.Add(new SeriesGenre
                    {
                        SeriesId = series.Id,
                        GenreId = genreId
                    });
                }
            }

            if (incomingActorLinks.Count > 0)
            {
                foreach (var link in incomingActorLinks)
                {
                    _context.SeriesActors.Add(new SeriesActor
                    {
                        SeriesId = series.Id,
                        ActorId = link.ActorId,
                        RoleName = link.RoleName
                    });
                }
            }

            if (incomingGenreIds.Count > 0 || incomingActorLinks.Count > 0)
            {
                _context.SaveChanges();
            }

            _context.Entry(series)
                .Collection(s => s.SeriesGenres)
                .Query()
                .Include(sg => sg.Genre)
                .Load();

            _context.Entry(series)
                .Collection(s => s.SeriesActors)
                .Query()
                .Include(sa => sa.Actor)
                .Load();

            HydrateSeries(series);

            _logger.LogInformation("Series {Title} created with id {SeriesId}.", series.Title, series.Id);
        }

        public void Update(Series series)
        {
            if (series == null)
                throw new ArgumentNullException(nameof(series));

            _logger.LogInformation("Updating series {SeriesId}", series.Id);

            var existing = _context.Series
                                  .Include(s => s.SeriesGenres)
                                  .Include(s => s.SeriesActors)
                                  .FirstOrDefault(s => s.Id == series.Id);

            if (existing == null)
            {
                _logger.LogWarning("Series {SeriesId} not found for update.", series.Id);
                throw new KeyNotFoundException($"Series with ID {series.Id} not found.");
            }

            if (string.IsNullOrWhiteSpace(series.Title))
                throw new ArgumentException("Series title cannot be empty.", nameof(series));

            existing.Title = series.Title;
            existing.Description = series.Description;
            existing.ReleaseDate = series.ReleaseDate;
            existing.Genre = series.Genre;
            existing.Rating = series.Rating;
            // Only update ImageUrl if a new value is provided (preserve existing image if not specified)
            if (!string.IsNullOrWhiteSpace(series.ImageUrl))
            {
            existing.ImageUrl = series.ImageUrl;
            }

            var incomingGenreIds = ExtractGenreIds(series);
            var incomingActorLinks = ExtractActorLinks(series);

            existing.SeriesGenres.Clear();
            if (incomingGenreIds.Count > 0)
            {
                foreach (var genreId in incomingGenreIds)
                {
                    existing.SeriesGenres.Add(new SeriesGenre
                    {
                        SeriesId = existing.Id,
                        GenreId = genreId
                    });
                }
            }

            existing.SeriesActors.Clear();
            if (incomingActorLinks.Count > 0)
            {
                foreach (var link in incomingActorLinks)
                {
                    existing.SeriesActors.Add(new SeriesActor
                    {
                        SeriesId = existing.Id,
                        ActorId = link.ActorId,
                        RoleName = link.RoleName
                    });
                }
            }

            _context.SaveChanges();

            _context.Entry(existing)
                .Collection(s => s.SeriesGenres)
                .Query()
                .Include(sg => sg.Genre)
                .Load();

            _context.Entry(existing)
                .Collection(s => s.SeriesActors)
                .Query()
                .Include(sa => sa.Actor)
                .Load();

            HydrateSeries(existing);

            // Reflect updates back to the incoming instance for controller responses
            series.SeriesGenres = existing.SeriesGenres.ToList();
            series.SeriesActors = existing.SeriesActors.ToList();
            series.Genres = existing.Genres.ToList();
            series.Actors = existing.Actors.ToList();

            _logger.LogInformation("Series {SeriesId} updated successfully.", series.Id);
        }

        public void Delete(int id)
        {
            _logger.LogInformation("Deleting series {SeriesId}", id);
            var series = _context.Series
                               .Include(s => s.Seasons)
                               .FirstOrDefault(s => s.Id == id);

            if (series == null)
            {
                _logger.LogWarning("Series {SeriesId} not found for deletion.", id);
                throw new KeyNotFoundException($"Series with ID {id} not found.");
            }

            _context.Series.Remove(series);
            _context.SaveChanges();
            _logger.LogInformation("Series {SeriesId} deleted successfully.", id);
        }

        public async Task<List<SeriesRecommendationDto>> GetRecommendationsAsync(int userId, int maxResults = 10)
        {
            _logger.LogInformation("Generating recommendations for user {UserId} with max results {MaxResults}.", userId, maxResults);

            if (maxResults <= 0)
            {
                maxResults = 10;
            }

            var userRatings = await _context.Ratings
                .AsNoTracking()
                .Where(r => r.UserId == userId)
                .ToListAsync();

            if (userRatings.Count == 0)
            {
                _logger.LogInformation("No ratings found for user {UserId}; returning empty recommendations.", userId);
                return new List<SeriesRecommendationDto>();
            }

            var highRatedSeriesIds = userRatings
                .Where(r => r.Score >= 8)
                .Select(r => r.SeriesId)
                .Distinct()
                .ToList();

            if (highRatedSeriesIds.Count == 0)
            {
                _logger.LogInformation("User {UserId} has no high-rated series; returning empty recommendations.", userId);
                return new List<SeriesRecommendationDto>();
            }

            var ratedSeriesIds = userRatings
                .Select(r => r.SeriesId)
                .Distinct()
                .ToList();

            var favoriteGenreIds = await _context.SeriesGenres
                .AsNoTracking()
                .Where(sg => highRatedSeriesIds.Contains(sg.SeriesId))
                .GroupBy(sg => sg.GenreId)
                .Select(g => new { GenreId = g.Key, Count = g.Count() })
                .OrderByDescending(g => g.Count)
                .Select(g => g.GenreId)
                .ToListAsync();

            if (favoriteGenreIds.Count == 0)
            {
                _logger.LogInformation("No dominant genres found for user {UserId}.", userId);
                return new List<SeriesRecommendationDto>();
            }

            // Get series with their ratings and users for filtering
            var candidateSeries = await _context.Series
                .AsNoTracking()
                .Include(s => s.Ratings)
                    .ThenInclude(r => r.User)
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Where(s =>
                    s.SeriesGenres.Any(sg => favoriteGenreIds.Contains(sg.GenreId)) &&
                    !ratedSeriesIds.Contains(s.Id))
                .ToListAsync();

            // Filter ratings using the same logic as GetByIdAsync and PopulateFeedbackCountsAsync
            // Include mobile and desktop users (seminar test users), exclude other test users
            var recommendationData = candidateSeries
                .Select(s =>
                {
                    // Filter ratings - same logic as GetByIdAsync
                    var realRatings = s.Ratings?
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
                        .ToList() ?? new List<Rating>();

                    // Use Series.Rating from database (which should be updated by GetByIdAsync/PopulateFeedbackCountsAsync)
                    // If not available, calculate from filtered ratings
                    var averageRating = s.Rating > 0 ? s.Rating : 
                        (realRatings.Any() ? Math.Round(realRatings.Average(r => r.Score), 2) : 0.0);

                    return new
                {
                        s.Id,
                    s.Title,
                        Genres = s.SeriesGenres
                            .Where(sg => sg.Genre != null)
                            .Select(sg => sg.Genre!.Name)
                            .Where(name => !string.IsNullOrWhiteSpace(name))
                            .Distinct()
                            .ToList(),
                        AverageRating = averageRating
                    };
                })
                .OrderByDescending(s => s.AverageRating)
                .ThenBy(s => s.Title)
                .Take(maxResults)
                .ToList();

            // Get series details for Id and ImageUrl
            var seriesDetails = await _context.Series
                .AsNoTracking()
                .Where(s => recommendationData.Select(r => r.Id).Contains(s.Id))
                .Select(s => new { s.Id, s.ImageUrl })
                .ToDictionaryAsync(s => s.Id, s => s.ImageUrl);

            var recommendations = recommendationData
                .Select(s => new SeriesRecommendationDto
                {
                    Id = s.Id,
                    Title = s.Title,
                    ImageUrl = seriesDetails.TryGetValue(s.Id, out var imageUrl) ? imageUrl : null,
                    Genres = s.Genres
                        .Where(name => !string.IsNullOrWhiteSpace(name))
                        .Select(name => name!)
                        .Distinct()
                        .ToList(),
                    AverageRating = Math.Round(s.AverageRating, 2)
                })
                .ToList();

            _logger.LogInformation("Generated {Count} recommendations for user {UserId}.", recommendations.Count, userId);

            return recommendations;
        }

        private List<int> ExtractGenreIds(Series series)
        {
            var genreIds = new HashSet<int>();

            if (series.SeriesGenres != null)
            {
                foreach (var link in series.SeriesGenres)
                {
                    var id = link.GenreId != 0 ? link.GenreId : link.Genre?.Id ?? 0;
                    if (id > 0)
                    {
                        genreIds.Add(id);
                    }
                }
            }

            if (series.Genres != null)
            {
                foreach (var genre in series.Genres)
                {
                    if (genre?.Id > 0)
                    {
                        genreIds.Add(genre.Id);
                    }
                }
            }

            return genreIds.ToList();
        }

        private List<(int ActorId, string? RoleName)> ExtractActorLinks(Series series)
        {
            var actorLinks = new Dictionary<int, string?>();

            if (series.SeriesActors != null)
            {
                foreach (var link in series.SeriesActors)
                {
                    var id = link.ActorId != 0 ? link.ActorId : link.Actor?.Id ?? 0;
                    if (id > 0 && !actorLinks.ContainsKey(id))
                    {
                        var roleName = string.IsNullOrWhiteSpace(link.RoleName) ? null : link.RoleName.Trim();
                        actorLinks[id] = roleName;
                    }
                }
            }

            if (series.Actors != null)
            {
                foreach (var actor in series.Actors)
                {
                    if (actor?.Id > 0 && !actorLinks.ContainsKey(actor.Id))
                    {
                        actorLinks[actor.Id] = null;
                    }
                }
            }

            return actorLinks
                .Select(kvp => (kvp.Key, kvp.Value))
                .Select(tuple => (ActorId: tuple.Key, RoleName: tuple.Value))
                .ToList();
        }

        private void HydrateSeries(Series series)
        {
            series.Genres = series.SeriesGenres?
                .Where(sg => sg.Genre != null)
                .Select(sg => sg.Genre!)
                .DistinctBy(g => g.Id)
                .ToList() ?? new List<Genre>();

            series.Actors = series.SeriesActors?
                .Where(sa => sa.Actor != null)
                .Select(sa => sa.Actor!)
                .DistinctBy(a => a.Id)
                .ToList() ?? new List<Actor>();

            if (series.Seasons != null)
            {
                var orderedSeasons = series.Seasons
                    .OrderBy(s => s.SeasonNumber)
                    .Select(s =>
                    {
                        if (s.Episodes != null)
                        {
                            var episodes = s.Episodes
                                .OrderBy(e => e.EpisodeNumber)
                                .ToList();
                            
                            // Check if episode 1 exists - log warning if missing
                            var hasEpisode1 = episodes.Any(e => e.EpisodeNumber == 1);
                            if (!hasEpisode1 && episodes.Count > 0)
                            {
                                _logger.LogWarning(
                                    "Season {SeasonId} (Season {SeasonNumber}) of Series {SeriesId} ({SeriesTitle}) is missing episode 1. " +
                                    "Found {EpisodeCount} episodes: {EpisodeNumbers}",
                                    s.Id, s.SeasonNumber, series.Id, series.Title, 
                                    episodes.Count, 
                                    string.Join(", ", episodes.Select(e => $"E{e.EpisodeNumber}")));
                            }
                            
                            s.Episodes = episodes;
                        }
                        else
                        {
                            s.Episodes = new List<Episode>();
                        }

                        return s;
                    })
                    .ToList();

                series.Seasons = orderedSeasons;
            }
            else
            {
                series.Seasons = new List<Season>();
            }

            // Filter out test/dummy user ratings - only keep real user reviews
            if (series.Ratings != null)
            {
                series.Ratings = series.Ratings
                    .Where(r => r.User != null 
                        && r.User.Email != null
                        && !r.User.Email.EndsWith("@test.com", StringComparison.OrdinalIgnoreCase)
                        && !r.User.Email.EndsWith("@example.com", StringComparison.OrdinalIgnoreCase)
                        && !r.User.Email.EndsWith("@test", StringComparison.OrdinalIgnoreCase))
                    .ToList();
            }
            else
            {
                series.Ratings = new List<Rating>();
            }
            
            series.Watchlists ??= new List<Watchlist>();
        }

        private async Task PopulateFeedbackCountsAsync(List<Series> seriesList)
        {
            if (seriesList == null || seriesList.Count == 0)
            {
                return;
            }

            var seriesIds = seriesList.Select(s => s.Id).ToList();

            // Get ALL ratings for these series (we'll filter later for display, but count all for ratingsCount)
            var allRatings = _context.Ratings
                .AsNoTracking()
                .Include(r => r.User)
                .Where(r => seriesIds.Contains(r.SeriesId))
                .ToList();
            
            _logger.LogDebug("PopulateFeedbackCountsAsync: Found {Count} total ratings for {SeriesCount} series",
                allRatings.Count, seriesIds.Count);
            
            // For ratingsCount, count ALL ratings (including test users) - this is what users see
            // The filtering is only for calculating average rating, not for count
            var ratingCounts = allRatings
                .GroupBy(r => r.SeriesId)
                .ToDictionary(g => g.Key, g => g.Count());
            
            _logger.LogDebug("PopulateFeedbackCountsAsync: Rating counts for {SeriesCount} series",
                ratingCounts.Count);
            
            // Calculate average ratings for each series and update Series.Rating property
            var seriesRatings = allRatings
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
                .GroupBy(r => r.SeriesId)
                .ToDictionary(g => g.Key, g => Math.Round(g.Average(r => r.Score), 2));

            // Get watchlist counts, filtering out test users
            // Materialize first, then filter in memory since EF Core can't translate EndsWith with StringComparison
            var allWatchlists = _context.Watchlists
                .AsNoTracking()
                .Include(w => w.User)
                .Where(w => seriesIds.Contains(w.SeriesId))
                .ToList();

            var watchlistCounts = allWatchlists
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
                .GroupBy(w => w.SeriesId)
                .ToDictionary(g => g.Key, g => g.Count());

            // Update ratings in database for all series that have ratings
            var seriesToUpdate = new List<(int SeriesId, double NewRating)>();

            foreach (var series in seriesList)
            {
                series.RatingsCount = ratingCounts.TryGetValue(series.Id, out var ratingCount) ? ratingCount : 0;
                series.WatchlistsCount = watchlistCounts.TryGetValue(series.Id, out var watchlistCount) ? watchlistCount : 0;
                
                // Update Series.Rating to reflect current average from user ratings if available
                // Always use the calculated average for display to ensure consistency
                if (seriesRatings.TryGetValue(series.Id, out var averageRating))
                {
                    // Check if rating needs to be updated in database
                    if (Math.Abs(series.Rating - averageRating) > 0.01)
                    {
                        seriesToUpdate.Add((series.Id, averageRating));
                        _logger.LogDebug("Series {SeriesId} rating needs update: {OldRating} -> {NewRating}",
                            series.Id, series.Rating, averageRating);
                    }
                    
                    // Update in-memory object for current response
                    series.Rating = averageRating;
                }
                // If no ratings, keep the manually entered fallback value (series.Rating already set)
            }
            
            // CRITICAL: Always update Series.Rating in database to ensure consistency
            // This ensures desktop, mobile, and recommendations all use the same rating
            if (seriesToUpdate.Any())
            {
                try
                {
                    // Use a separate context or detach entities to avoid conflicts
                    foreach (var (seriesId, newRating) in seriesToUpdate)
                    {
                        var seriesInDb = await _context.Series.FindAsync(seriesId);
                        if (seriesInDb != null)
                        {
                            seriesInDb.Rating = newRating;
                        }
                    }
                    
                    await _context.SaveChangesAsync();
                    _logger.LogInformation("Updated {Count} series ratings in database from PopulateFeedbackCountsAsync",
                        seriesToUpdate.Count);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error updating series ratings in database from PopulateFeedbackCountsAsync. Continuing with in-memory updates.");
                    // Don't throw - continue with in-memory updates
                }
            }
        }
    }
}
