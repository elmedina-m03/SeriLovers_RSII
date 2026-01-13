using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Services
{
    /// <summary>
    /// Hybrid recommendation system combining:
    /// 1. Item-based filtering (genre similarity)
    /// 2. User-based collaborative filtering (similar users)
    /// </summary>
    public class RecommendationService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<RecommendationService> _logger;

        private const double ItemBasedWeight = 0.6;
        private const double UserBasedWeight = 0.4;

        public RecommendationService(ApplicationDbContext context, ILogger<RecommendationService> logger)
        {
            _context = context;
            _logger = logger;
        }

        /// <summary>
        /// Gets personalized recommendations using hybrid approach:
        /// - Item-based filtering: Find series similar to user's liked series (by genre)
        /// - User-based filtering: Find similar users and recommend what they liked
        /// </summary>
        public async Task<List<SeriesRecommendationDto>> GetRecommendationsAsync(int userId, int maxResults = 10)
        {
            _logger.LogInformation("Generating hybrid recommendations for user {UserId}", userId);

            // Get user's watched and rated series
            var userSeriesData = await GetUserSeriesDataAsync(userId);

            // Fallback for new users
            if (userSeriesData.WatchedSeriesIds.Count == 0 && userSeriesData.RatedSeriesIds.Count == 0)
            {
                _logger.LogInformation("User {UserId} has no history; returning popular series", userId);
                return await GetFallbackRecommendationsAsync(maxResults, null);
            }

            // Get candidate series (not watched/rated by user)
            var candidateSeries = await GetCandidateSeriesAsync(userId, userSeriesData.AllSeriesIds);

            if (candidateSeries.Count == 0)
            {
                _logger.LogInformation("No candidate series found for user {UserId}", userId);
                return await GetFallbackRecommendationsAsync(maxResults, userSeriesData.AllSeriesIds);
            }

            // Calculate item-based scores (genre similarity)
            var itemBasedScores = CalculateItemBasedScores(userSeriesData, candidateSeries);

            // Calculate user-based scores (similar users)
            var userBasedScores = await CalculateUserBasedScoresAsync(userId, userSeriesData, candidateSeries);

            // Combine scores
            var combinedRecommendations = await CombineRecommendationsAsync(
                candidateSeries,
                itemBasedScores,
                userBasedScores,
                maxResults);

            _logger.LogInformation(
                "Generated {Count} recommendations for user {UserId} (Item-based: {ItemCount}, User-based: {UserCount})",
                combinedRecommendations.Count,
                userId,
                itemBasedScores.Count(s => s.Value > 0),
                userBasedScores.Count(s => s.Value > 0));

            return combinedRecommendations;
        }

        #region Data Preparation

        private async Task<UserSeriesData> GetUserSeriesDataAsync(int userId)
        {
            // Get watched series (from episode progress)
            var watchedSeriesIds = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId && ep.IsCompleted)
                .Select(ep => ep.Episode.Season.SeriesId)
                .Distinct()
                .ToListAsync();

            // Get rated series with ratings
            var ratedSeries = await _context.Ratings
                .Where(r => r.UserId == userId)
                .Select(r => new { r.SeriesId, r.Score })
                .ToListAsync();

            var ratedSeriesIds = ratedSeries.Select(r => r.SeriesId).Distinct().ToList();

            // Get user's series with genres for item-based filtering
            var userSeries = await _context.Series
                .AsNoTracking()
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Where(s => watchedSeriesIds.Contains(s.Id) || ratedSeriesIds.Contains(s.Id))
                .ToListAsync();

            // Build rating map (seriesId -> rating)
            var ratingMap = ratedSeries.ToDictionary(r => r.SeriesId, r => r.Score);

            return new UserSeriesData
            {
                WatchedSeriesIds = watchedSeriesIds.ToHashSet(),
                RatedSeriesIds = ratedSeriesIds.ToHashSet(),
                AllSeriesIds = watchedSeriesIds.Union(ratedSeriesIds).ToHashSet(),
                UserSeries = userSeries,
                RatingMap = ratingMap
            };
        }

        private async Task<List<Series>> GetCandidateSeriesAsync(int userId, HashSet<int> excludeSeriesIds)
        {
            return await _context.Series
                .AsNoTracking()
                .AsSplitQuery()
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Include(s => s.Ratings)
                .Where(s => !excludeSeriesIds.Contains(s.Id) && s.Ratings.Any()) // Only include series that have at least one rating
                .ToListAsync();
        }

        #endregion

        #region Item-Based Filtering (Genre Similarity)

        /// <summary>
        /// Item-based filtering: Find series similar to user's liked series based on genre overlap.
        /// Uses Jaccard similarity: intersection / union of genres
        /// </summary>
        private Dictionary<int, double> CalculateItemBasedScores(
            UserSeriesData userData,
            List<Series> candidateSeries)
        {
            var scores = new Dictionary<int, double>();

            // Build genre sets for user's liked series (weighted by rating)
            var userGenreProfile = BuildUserGenreProfile(userData);

            if (userGenreProfile.Count == 0)
            {
                _logger.LogWarning("User has no genre preferences for item-based filtering");
                return scores;
            }

            foreach (var series in candidateSeries)
            {
                var seriesGenres = series.SeriesGenres
                    .Where(sg => sg.Genre != null)
                    .Select(sg => sg.Genre!.Name)
                    .ToHashSet();

                if (seriesGenres.Count == 0)
                    continue;

                var similarity = CalculateWeightedJaccardSimilarity(userGenreProfile, seriesGenres);
                scores[series.Id] = similarity;
            }

            return scores;
        }

        /// <summary>
        /// Builds a weighted genre profile from user's series (weighted by ratings)
        /// </summary>
        private Dictionary<string, double> BuildUserGenreProfile(UserSeriesData userData)
        {
            var genreWeights = new Dictionary<string, double>();

            foreach (var series in userData.UserSeries)
            {
                // Get user's rating for this series (default to 5 if not rated)
                var rating = userData.RatingMap.GetValueOrDefault(series.Id, 5);
                var weight = (rating - 1.0) / 9.0;

                foreach (var sg in series.SeriesGenres)
                {
                    if (sg.Genre != null)
                    {
                        var genreName = sg.Genre.Name;
                        if (!genreWeights.ContainsKey(genreName))
                        {
                            genreWeights[genreName] = 0;
                        }
                        genreWeights[genreName] += weight;
                    }
                }
            }

            return genreWeights;
        }

        /// <summary>
        /// Calculates weighted Jaccard similarity between user's genre profile and series genres
        /// </summary>
        private double CalculateWeightedJaccardSimilarity(
            Dictionary<string, double> userGenreProfile,
            HashSet<string> seriesGenres)
        {
            if (seriesGenres.Count == 0)
                return 0;

            // Calculate intersection (matching genres) - weighted by user preference
            double intersection = 0;
            foreach (var genre in seriesGenres)
            {
                if (userGenreProfile.ContainsKey(genre))
                {
                    intersection += userGenreProfile[genre];
                }
            }

            // Calculate union (all genres from both)
            var union = userGenreProfile.Values.Sum() + seriesGenres.Count;

            // Weighted Jaccard: intersection / union
            return union > 0 ? intersection / union : 0;
        }

        #endregion

        #region User-Based Collaborative Filtering

        /// <summary>
        /// User-based filtering: Find users similar to current user, then recommend what they liked.
        /// Uses cosine similarity on user rating vectors.
        /// </summary>
        private async Task<Dictionary<int, double>> CalculateUserBasedScoresAsync(
            int userId,
            UserSeriesData userData,
            List<Series> candidateSeries)
        {
            var scores = new Dictionary<int, double>();

            // Get all users who have rated/watched series
            var allUsers = await _context.Users
                .Select(u => u.Id)
                .Where(id => id != userId) // Exclude current user
                .ToListAsync();

            if (allUsers.Count == 0)
            {
                _logger.LogInformation("No other users found for user-based filtering");
                return scores;
            }

            // Build current user's rating vector
            var currentUserVector = BuildUserRatingVector(userId, userData);

            if (currentUserVector.Count == 0)
            {
                _logger.LogInformation("Current user has no ratings for user-based filtering");
                return scores;
            }

            // Find similar users
            var similarUsers = await FindSimilarUsersAsync(userId, currentUserVector, allUsers);

            if (similarUsers.Count == 0)
            {
                _logger.LogInformation("No similar users found for user {UserId}", userId);
                return scores;
            }

            // Calculate scores based on what similar users liked
            scores = CalculateScoresFromSimilarUsers(similarUsers, candidateSeries);

            _logger.LogInformation(
                "User-based filtering found {Count} similar users and scored {ScoreCount} series",
                similarUsers.Count,
                scores.Count);

            return scores;
        }

        /// <summary>
        /// Builds a rating vector for the user (seriesId -> normalized rating)
        /// </summary>
        private Dictionary<int, double> BuildUserRatingVector(int userId, UserSeriesData userData)
        {
            var vector = new Dictionary<int, double>();

            // Include rated series
            foreach (var (seriesId, rating) in userData.RatingMap)
            {
                // Normalize rating to 0-1 scale (ratings are 1-10)
                vector[seriesId] = (rating - 1) / 9.0;
            }

            // Include watched series (implicit positive rating of 0.5)
            foreach (var seriesId in userData.WatchedSeriesIds)
            {
                if (!vector.ContainsKey(seriesId))
                {
                    vector[seriesId] = 0.5; // Implicit positive rating
                }
            }

            return vector;
        }

        /// <summary>
        /// Finds users similar to current user using cosine similarity
        /// </summary>
        private async Task<List<SimilarUser>> FindSimilarUsersAsync(
            int userId,
            Dictionary<int, double> currentUserVector,
            List<int> allUserIds)
        {
            var similarUsers = new List<SimilarUser>();

            // Get all series IDs that appear in current user's vector
            var seriesIds = currentUserVector.Keys.ToList();

            foreach (var otherUserId in allUserIds)
            {
                // Build other user's rating vector for common series
                var otherUserRatings = await _context.Ratings
                    .Where(r => r.UserId == otherUserId && seriesIds.Contains(r.SeriesId))
                    .Select(r => new { r.SeriesId, r.Score })
                    .ToListAsync();

                // Include watched series as implicit ratings
                var otherUserWatched = await _context.EpisodeProgresses
                    .Where(ep => ep.UserId == otherUserId 
                              && ep.IsCompleted 
                              && seriesIds.Contains(ep.Episode.Season.SeriesId))
                    .Select(ep => ep.Episode.Season.SeriesId)
                    .Distinct()
                    .ToListAsync();

                var otherUserVector = new Dictionary<int, double>();
                foreach (var rating in otherUserRatings)
                {
                    otherUserVector[rating.SeriesId] = (rating.Score - 1) / 9.0;
                }
                foreach (var seriesId in otherUserWatched)
                {
                    if (!otherUserVector.ContainsKey(seriesId))
                    {
                        otherUserVector[seriesId] = 0.5;
                    }
                }

                // Calculate cosine similarity
                var similarity = CalculateCosineSimilarity(currentUserVector, otherUserVector);

                if (similarity > 0.1)
                {
                    similarUsers.Add(new SimilarUser
                    {
                        UserId = otherUserId,
                        Similarity = similarity,
                        RatingVector = otherUserVector
                    });
                }
            }

            return similarUsers
                .OrderByDescending(u => u.Similarity)
                .Take(20)
                .ToList();
        }

        /// <summary>
        /// Calculates cosine similarity between two rating vectors
        /// </summary>
        private double CalculateCosineSimilarity(
            Dictionary<int, double> vector1,
            Dictionary<int, double> vector2)
        {
            // Get common series
            var commonSeries = vector1.Keys.Intersect(vector2.Keys).ToList();

            if (commonSeries.Count == 0)
                return 0;

            // Calculate dot product
            double dotProduct = 0;
            foreach (var seriesId in commonSeries)
            {
                dotProduct += vector1[seriesId] * vector2[seriesId];
            }

            // Calculate magnitudes
            double magnitude1 = Math.Sqrt(vector1.Values.Sum(v => v * v));
            double magnitude2 = Math.Sqrt(vector2.Values.Sum(v => v * v));

            if (magnitude1 == 0 || magnitude2 == 0)
                return 0;

            // Cosine similarity: dot product / (magnitude1 * magnitude2)
            return dotProduct / (magnitude1 * magnitude2);
        }

        /// <summary>
        /// Calculates recommendation scores based on what similar users liked
        /// </summary>
        private Dictionary<int, double> CalculateScoresFromSimilarUsers(
            List<SimilarUser> similarUsers,
            List<Series> candidateSeries)
        {
            var scores = new Dictionary<int, double>();

            foreach (var series in candidateSeries)
            {
                double weightedScore = 0;
                double totalSimilarity = 0;

                foreach (var similarUser in similarUsers)
                {
                    // Check if similar user has rated/watched this series
                    if (similarUser.RatingVector.ContainsKey(series.Id))
                    {
                        var userRating = similarUser.RatingVector[series.Id];
                        weightedScore += userRating * similarUser.Similarity;
                        totalSimilarity += similarUser.Similarity;
                    }
                }

                if (totalSimilarity > 0)
                {
                    // Normalize by total similarity
                    scores[series.Id] = weightedScore / totalSimilarity;
                }
            }

            return scores;
        }

        #endregion

        #region Score Combination and Result Generation

        /// <summary>
        /// Combines item-based and user-based scores into final recommendations
        /// </summary>
        private async Task<List<SeriesRecommendationDto>> CombineRecommendationsAsync(
            List<Series> candidateSeries,
            Dictionary<int, double> itemBasedScores,
            Dictionary<int, double> userBasedScores,
            int maxResults)
        {
            var combinedScores = new Dictionary<int, CombinedScore>();

            foreach (var series in candidateSeries)
            {
                var itemScore = itemBasedScores.GetValueOrDefault(series.Id, 0);
                var userScore = userBasedScores.GetValueOrDefault(series.Id, 0);

                // Combine scores with weights
                var combinedScore = (itemScore * ItemBasedWeight) + (userScore * UserBasedWeight);

                if (combinedScore > 0)
                {
                    combinedScores[series.Id] = new CombinedScore
                    {
                        Series = series,
                        ItemBasedScore = itemScore,
                        UserBasedScore = userScore,
                        FinalScore = combinedScore
                    };
                }
            }

            var recommendations = combinedScores.Values
                .OrderByDescending(s => s.FinalScore)
                .Take(maxResults)
                .Select(s => new SeriesRecommendationDto
                {
                    Id = s.Series.Id,
                    Title = s.Series.Title,
                    ImageUrl = s.Series.ImageUrl,
                    Genres = s.Series.SeriesGenres
                        .Where(sg => sg.Genre != null)
                        .Select(sg => sg.Genre!.Name)
                        .Where(name => !string.IsNullOrEmpty(name))
                        .Distinct()
                        .ToList(),
                    // Use Series.Rating from database (already filtered and updated by SeriesService)
                    // This ensures consistency with desktop and mobile displays
                    AverageRating = Math.Round(s.Series.Rating, 2),
                    SimilarityScore = Math.Round(s.FinalScore, 3),
                    Reason = GenerateRecommendationReason(s)
                })
                .ToList();

            if (recommendations.Count < maxResults)
            {
                var existingIds = recommendations.Select(r => r.Id).ToHashSet();
                var fallback = await GetFallbackRecommendationsAsync(
                    maxResults - recommendations.Count,
                    existingIds);

                recommendations.AddRange(fallback);
            }

            return recommendations;
        }

        private string GenerateRecommendationReason(CombinedScore score)
        {
            var reasons = new List<string>();

            if (score.ItemBasedScore > 0.3)
            {
                reasons.Add("Similar genres to your favorites");
            }

            if (score.UserBasedScore > 0.3)
            {
                reasons.Add("Liked by users with similar taste");
            }

            if (reasons.Any())
            {
                return string.Join(" • ", reasons);
            }

            return "Recommended for you";
        }

        #endregion

        #region Fallback Recommendations

        private async Task<List<SeriesRecommendationDto>> GetFallbackRecommendationsAsync(
            int maxResults,
            HashSet<int>? excludeSeriesIds = null)
        {
            var query = _context.Series
                .AsNoTracking()
                .AsSplitQuery()
                .Include(s => s.SeriesGenres)
                    .ThenInclude(sg => sg.Genre)
                .Include(s => s.Ratings)
                .AsQueryable();

            if (excludeSeriesIds != null && excludeSeriesIds.Any())
            {
                query = query.Where(s => !excludeSeriesIds.Contains(s.Id));
            }

            var popularSeries = await query
                .Where(s => s.Ratings.Any()) // Only include series that have at least one rating
                .Select(s => new
                {
                    Series = s,
                    PopularityScore = s.Ratings.Count() + s.Watchlists.Count(),
                    // Use Series.Rating from database (already filtered and updated by SeriesService)
                    // This ensures consistency with desktop and mobile displays
                    AverageRating = s.Rating
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
                    .Where(sg => sg.Genre != null && !string.IsNullOrEmpty(sg.Genre.Name))
                    .Select(sg => sg.Genre!.Name)
                    .Distinct()
                    .ToList(),
                AverageRating = Math.Round(s.AverageRating, 2),
                SimilarityScore = 0.0,
                Reason = "Popular and highly-rated series"
            }).ToList();
        }

        #endregion

        #region Helper Classes

        private class UserSeriesData
        {
            public HashSet<int> WatchedSeriesIds { get; set; } = new();
            public HashSet<int> RatedSeriesIds { get; set; } = new();
            public HashSet<int> AllSeriesIds { get; set; } = new();
            public List<Series> UserSeries { get; set; } = new();
            public Dictionary<int, int> RatingMap { get; set; } = new(); // seriesId -> rating (1-10)
        }

        private class SimilarUser
        {
            public int UserId { get; set; }
            public double Similarity { get; set; }
            public Dictionary<int, double> RatingVector { get; set; } = new();
        }

        private class CombinedScore
        {
            public Series Series { get; set; } = null!;
            public double ItemBasedScore { get; set; }
            public double UserBasedScore { get; set; }
            public double FinalScore { get; set; }
        }

        #endregion
    }
}
