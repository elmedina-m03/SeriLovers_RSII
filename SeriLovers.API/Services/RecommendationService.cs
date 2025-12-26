using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace SeriLovers.API.Services
{
    public class RecommendationService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<RecommendationService> _logger;

        public RecommendationService(ApplicationDbContext context, ILogger<RecommendationService> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Gets personalized recommendations for a user using content-based filtering
        /// </summary>
        public async Task<List<SeriesRecommendationDto>> GetRecommendationsAsync(int userId, int maxResults = 10)
        {
            _logger.LogInformation("Generating content-based recommendations for user {UserId}", userId);

            // Get all series the user has watched or rated
            var watchedSeriesIds = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId && ep.IsCompleted)
                .Select(ep => ep.Episode.Season.SeriesId)
                .Distinct()
                .ToListAsync();

            var ratedSeriesIds = await _context.Ratings
                .Where(r => r.UserId == userId)
                .Select(r => r.SeriesId)
                .Distinct()
                .ToListAsync();

            var userSeriesIds = watchedSeriesIds.Union(ratedSeriesIds).Distinct().ToList();

            // Fallback for new users: return most popular/highest-rated series
            if (userSeriesIds.Count == 0)
            {
                _logger.LogInformation("User {UserId} has no watched/rated series; returning popular series as fallback", userId);
                return await GetFallbackRecommendationsAsync(maxResults);
            }

            // Get user's series with full details
            var userSeries = await _context.Series
                .AsNoTracking()
                .AsSplitQuery()
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Include(s => s.Ratings)
                .Where(s => userSeriesIds.Contains(s.Id))
                .ToListAsync();

            // Extract features from user's series
            var userProfile = BuildUserProfile(userSeries);

            // Get all series not watched/rated by user
            var candidateSeries = await _context.Series
                .AsNoTracking()
                .AsSplitQuery()
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Include(s => s.Ratings)
                .Where(s => !userSeriesIds.Contains(s.Id))
                .ToListAsync();

            if (candidateSeries.Count == 0)
            {
                _logger.LogInformation("No candidate series found for user {UserId}", userId);
                return await GetFallbackRecommendationsAsync(maxResults);
            }

            // Calculate similarity scores
            var recommendations = candidateSeries
                .Select(series =>
                {
                    var similarity = CalculateSimilarity(userProfile, series);
                    return new
                    {
                        Series = series,
                        SimilarityScore = similarity
                    };
                })
                .Where(r => r.SimilarityScore > 0)
                .OrderByDescending(r => r.SimilarityScore)
                .Take(maxResults)
                .Select(r => new SeriesRecommendationDto
                {
                    Id = r.Series.Id,
                    Title = r.Series.Title,
                    ImageUrl = r.Series.ImageUrl,
                    Genres = r.Series.SeriesGenres
                        .Where(sg => sg.Genre != null)
                        .Select(sg => sg.Genre!.Name)
                        .Distinct()
                        .ToList(),
                    AverageRating = r.Series.Ratings.Any()
                        ? Math.Round(r.Series.Ratings.Average(rat => rat.Score), 2)
                        : 0.0,
                    SimilarityScore = Math.Round(r.SimilarityScore, 3),
                    Reason = GenerateRecommendationReason(r.SimilarityScore, userProfile, r.Series)
                })
                .ToList();

            _logger.LogInformation("Generated {Count} recommendations for user {UserId}", recommendations.Count, userId);
            return recommendations;
        }

        /// <summary>
        /// Builds a user profile from their watched/rated series
        /// </summary>
        private UserProfile BuildUserProfile(List<Series> userSeries)
        {
            var profile = new UserProfile();

            // Extract genres (weighted by rating if available)
            var genreWeights = new Dictionary<string, double>();
            var ratingWeights = new List<double>();
            var allKeywords = new List<string>();

            foreach (var series in userSeries)
            {
                var seriesRating = series.Ratings.Any() 
                    ? series.Ratings.Average(r => r.Score) 
                    : 5.0; // Default weight if no rating

                // Weight genres by rating
                foreach (var sg in series.SeriesGenres)
                {
                    if (sg.Genre != null)
                    {
                        var genreName = sg.Genre.Name;
                        if (!genreWeights.ContainsKey(genreName))
                        {
                            genreWeights[genreName] = 0;
                        }
                        genreWeights[genreName] += seriesRating;
                    }
                }

                ratingWeights.Add(seriesRating);

                // Extract keywords from description
                if (!string.IsNullOrWhiteSpace(series.Description))
                {
                    var keywords = ExtractKeywords(series.Description);
                    allKeywords.AddRange(keywords);
                }
            }

            profile.GenreWeights = genreWeights;
            profile.AverageRating = ratingWeights.Any() ? ratingWeights.Average() : 5.0;
            profile.Keywords = allKeywords
                .GroupBy(k => k.ToLower())
                .OrderByDescending(g => g.Count())
                .Take(20) // Top 20 keywords
                .Select(g => g.Key)
                .ToList();

            return profile;
        }

        /// <summary>
        /// Calculates similarity between user profile and a series using weighted matching
        /// </summary>
        private double CalculateSimilarity(UserProfile userProfile, Series series)
        {
            double similarity = 0.0;
            double totalWeight = 0.0;

            // Genre similarity (weight: 40%)
            var genreWeight = 0.4;
            var genreMatch = CalculateGenreSimilarity(userProfile.GenreWeights, series);
            similarity += genreMatch * genreWeight;
            totalWeight += genreWeight;

            // Rating similarity (weight: 30%)
            var ratingWeight = 0.3;
            var seriesRating = series.Ratings.Any() 
                ? series.Ratings.Average(r => r.Score) 
                : 0.0;
            var ratingMatch = CalculateRatingSimilarity(userProfile.AverageRating, seriesRating);
            similarity += ratingMatch * ratingWeight;
            totalWeight += ratingWeight;

            // Keyword similarity (weight: 30%)
            var keywordWeight = 0.3;
            var keywordMatch = CalculateKeywordSimilarity(userProfile.Keywords, series.Description ?? "");
            similarity += keywordMatch * keywordWeight;
            totalWeight += keywordWeight;

            return totalWeight > 0 ? similarity / totalWeight : 0.0;
        }

        /// <summary>
        /// Calculates genre similarity using weighted matching
        /// </summary>
        private double CalculateGenreSimilarity(Dictionary<string, double> userGenreWeights, Series series)
        {
            if (!userGenreWeights.Any())
                return 0.0;

            var seriesGenres = series.SeriesGenres
                .Where(sg => sg.Genre != null)
                .Select(sg => sg.Genre!.Name)
                .ToList();

            if (!seriesGenres.Any())
                return 0.0;

            double matchScore = 0.0;
            double totalWeight = userGenreWeights.Values.Sum();

            foreach (var genre in seriesGenres)
            {
                if (userGenreWeights.ContainsKey(genre))
                {
                    matchScore += userGenreWeights[genre];
                }
            }

            return totalWeight > 0 ? matchScore / totalWeight : 0.0;
        }

        /// <summary>
        /// Calculates rating similarity (prefers similar ratings)
        /// </summary>
        private double CalculateRatingSimilarity(double userAvgRating, double seriesRating)
        {
            if (seriesRating == 0)
                return 0.3; // Neutral score for unrated series

            var difference = Math.Abs(userAvgRating - seriesRating);
            // Normalize to 0-1 scale (max difference is 9, since ratings are 1-10)
            var similarity = 1.0 - (difference / 9.0);
            return Math.Max(0.0, Math.Min(1.0, similarity));
        }

        /// <summary>
        /// Calculates keyword similarity using simple word matching
        /// </summary>
        private double CalculateKeywordSimilarity(List<string> userKeywords, string seriesDescription)
        {
            if (!userKeywords.Any() || string.IsNullOrWhiteSpace(seriesDescription))
                return 0.0;

            var descriptionWords = ExtractKeywords(seriesDescription)
                .Select(w => w.ToLower())
                .Distinct()
                .ToList();

            if (!descriptionWords.Any())
                return 0.0;

            var matches = userKeywords.Count(keyword => descriptionWords.Contains(keyword));
            return (double)matches / userKeywords.Count;
        }

        /// <summary>
        /// Extracts keywords from text (simple word splitting, removes common stop words)
        /// </summary>
        private List<string> ExtractKeywords(string text)
        {
            var stopWords = new HashSet<string> { "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "are", "was", "were", "be", "been", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those", "i", "you", "he", "she", "it", "we", "they", "what", "which", "who", "when", "where", "why", "how" };

            var words = Regex.Split(text.ToLower(), @"\W+")
                .Where(w => w.Length > 3 && !stopWords.Contains(w))
                .Distinct()
                .ToList();

            return words;
        }

        /// <summary>
        /// Generates a human-readable reason for the recommendation
        /// </summary>
        private string GenerateRecommendationReason(double similarityScore, UserProfile userProfile, Series series)
        {
            var reasons = new List<string>();

            // Check genre match
            var seriesGenres = series.SeriesGenres
                .Where(sg => sg.Genre != null)
                .Select(sg => sg.Genre!.Name)
                .ToList();

            var matchingGenres = seriesGenres
                .Where(g => userProfile.GenreWeights.ContainsKey(g))
                .ToList();

            if (matchingGenres.Any())
            {
                reasons.Add($"Similar genres: {string.Join(", ", matchingGenres.Take(2))}");
            }

            // Check rating
            var seriesRating = series.Ratings.Any() 
                ? series.Ratings.Average(r => r.Score) 
                : 0.0;
            if (seriesRating > 0 && Math.Abs(seriesRating - userProfile.AverageRating) < 2.0)
            {
                reasons.Add($"Similar rating ({seriesRating:F1}/10)");
            }

            if (reasons.Any())
            {
                return string.Join(" • ", reasons);
            }

            return $"Similarity score: {similarityScore:F2}";
        }

        /// <summary>
        /// Returns fallback recommendations (most popular/highest-rated) for new users
        /// </summary>
        private async Task<List<SeriesRecommendationDto>> GetFallbackRecommendationsAsync(int maxResults)
        {
            var popularSeries = await _context.Series
                .AsNoTracking()
                .AsSplitQuery()
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Include(s => s.Ratings)
                .Include(s => s.Watchlists)
                .Select(s => new
                {
                    Series = s,
                    PopularityScore = s.Ratings.Count() + s.Watchlists.Count(),
                    AverageRating = s.Ratings.Any() ? s.Ratings.Average(r => r.Score) : 0.0
                })
                .OrderByDescending(s => s.AverageRating)
                .ThenByDescending(s => s.PopularityScore)
                .Take(maxResults)
                .ToListAsync();

            return popularSeries.Select(s => new SeriesRecommendationDto
            {
                Id = s.Series.Id,
                Title = s.Series.Title,
                ImageUrl = s.Series.ImageUrl,
                Genres = s.Series.SeriesGenres
                    .Where(sg => sg.Genre != null)
                    .Select(sg => sg.Genre!.Name)
                    .Distinct()
                    .ToList(),
                AverageRating = Math.Round(s.AverageRating, 2),
                SimilarityScore = 0.0,
                Reason = "Popular and highly-rated series"
            }).ToList();
        }

        /// <summary>
        /// Internal class to represent user profile
        /// </summary>
        private class UserProfile
        {
            public Dictionary<string, double> GenreWeights { get; set; } = new Dictionary<string, double>();
            public double AverageRating { get; set; }
            public List<string> Keywords { get; set; } = new List<string>();
        }
    }
}

