using AutoMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;
using SeriLovers.API.Domain.Exceptions;
using SeriLovers.API.Domain.StateMachine;
using SeriLovers.API.Models;
using System.Linq;

namespace SeriLovers.API.Services
{
    /// <summary>
    /// Service for managing series watching state with database persistence using State Pattern
    /// </summary>
    public class SeriesWatchingStateService : ISeriesWatchingStateService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<SeriesWatchingStateService> _logger;
        private readonly IServiceProvider _serviceProvider;
        private readonly IMapper _mapper;

        public SeriesWatchingStateService(
            ApplicationDbContext context,
            ILogger<SeriesWatchingStateService> logger,
            IServiceProvider serviceProvider,
            IMapper mapper)
        {
            _context = context;
            _logger = logger;
            _serviceProvider = serviceProvider;
            _mapper = mapper;
        }

        /// <inheritdoc />
        public async Task<SeriesWatchingStatus> GetStatusAsync(int userId, int seriesId)
        {
            // CRITICAL: First check if user has a review for this series
            // If they do, the series MUST be Finished (cannot revert to InProgress)
            var hasReview = await _context.Ratings
                .AnyAsync(r => r.UserId == userId && r.SeriesId == seriesId);
            
            if (hasReview)
            {
                _logger.LogDebug("Series {SeriesId} for User {UserId} has a review. Ensuring status is Finished.",
                    seriesId, userId);
                
                // Get or create state entity
                var stateEntity = await _context.SeriesWatchingStates
                    .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);
                
                if (stateEntity == null || stateEntity.Status != SeriesWatchingStatus.Finished)
                {
                    // Get series to calculate total episodes
                    var series = await _context.Series
                        .Include(s => s.Seasons)
                            .ThenInclude(season => season.Episodes)
                        .FirstOrDefaultAsync(s => s.Id == seriesId);
                    
                    if (series != null)
                    {
                        var totalEpisodes = (series.Seasons ?? Enumerable.Empty<Season>())
                            .SelectMany(season => season.Episodes ?? Enumerable.Empty<Episode>())
                            .Count();
                        
                        // Create or update state as Finished
                        if (stateEntity == null)
                        {
                            stateEntity = new SeriesWatchingState
                            {
                                UserId = userId,
                                SeriesId = seriesId,
                                Status = SeriesWatchingStatus.Finished,
                                WatchedEpisodesCount = totalEpisodes,
                                TotalEpisodesCount = totalEpisodes,
                                CreatedAt = DateTime.UtcNow,
                                LastUpdated = DateTime.UtcNow
                            };
                            _context.SeriesWatchingStates.Add(stateEntity);
                        }
                        else
                        {
                            stateEntity.Status = SeriesWatchingStatus.Finished;
                            stateEntity.WatchedEpisodesCount = totalEpisodes;
                            stateEntity.TotalEpisodesCount = totalEpisodes;
                            stateEntity.LastUpdated = DateTime.UtcNow;
                        }
                        
                        await _context.SaveChangesAsync();
                        _logger.LogInformation("Set Series {SeriesId} for User {UserId} to Finished status because review exists.",
                            seriesId, userId);
                    }
                }
                
                return SeriesWatchingStatus.Finished;
            }
            
            // No review - check existing state or calculate
            var existingState = await _context.SeriesWatchingStates
                .AsNoTracking()
                .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);

            if (existingState != null)
            {
                // For non-Finished statuses, return the stored status
                return existingState.Status;
            }

            // No state entity exists - calculate and persist
            return await CalculateAndPersistStatusAsync(userId, seriesId);
        }

        /// <inheritdoc />
        public async Task ValidateReviewCreationAsync(int userId, int seriesId)
        {
            var status = await GetStatusAsync(userId, seriesId);
            var currentState = BaseSeriesWatchingState.GetState(status, _serviceProvider);
            currentState.ValidateReviewCreation();
        }

        /// <inheritdoc />
        public async Task<SeriesWatchingStatus> UpdateStatusAsync(int userId, int seriesId)
        {
            try
            {
                var existingState = await _context.SeriesWatchingStates
                    .AsNoTracking()
                    .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);

                if (existingState == null)
                {
                    var initialState = new SeriesWatchingState
                    {
                        UserId = userId,
                        SeriesId = seriesId,
                        Status = SeriesWatchingStatus.ToWatch,
                        WatchedEpisodesCount = 0,
                        TotalEpisodesCount = 0,
                        CreatedAt = DateTime.UtcNow,
                        LastUpdated = DateTime.UtcNow
                    };
                    
                    _context.SeriesWatchingStates.Add(initialState);
                    
                    try
                    {
                        await _context.SaveChangesAsync();
                        
                        var verifyState = await _context.SeriesWatchingStates
                            .AsNoTracking()
                            .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);
                        
                        if (verifyState == null)
                        {
                            throw new InvalidOperationException($"Failed to create initial SeriesWatchingState. UserId={userId}, SeriesId={seriesId}");
                        }
                    }
                    catch (Exception saveEx)
                    {
                        _logger.LogError(saveEx, "Failed to save initial SeriesWatchingState. UserId={UserId}, SeriesId={SeriesId}", userId, seriesId);
                        throw;
                    }
                }

                var result = await CalculateAndPersistStatusAsync(userId, seriesId);
                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "UpdateStatusAsync failed. UserId={UserId}, SeriesId={SeriesId}", userId, seriesId);
                throw;
            }
        }

        private async Task<SeriesWatchingStatus> CalculateAndPersistStatusAsync(int userId, int seriesId)
        {
            var series = await _context.Series
                .Include(s => s.Seasons)
                    .ThenInclude(season => season.Episodes)
                .FirstOrDefaultAsync(s => s.Id == seriesId);

            if (series == null)
            {
                _logger.LogError("Series not found: SeriesId={SeriesId}", seriesId);
                throw new ArgumentException($"Series with ID {seriesId} not found", nameof(seriesId));
            }

            var totalEpisodes = (series.Seasons ?? Enumerable.Empty<Season>())
                .SelectMany(season => season.Episodes ?? Enumerable.Empty<Episode>())
                .Count();

            if (totalEpisodes == 0)
            {
                var toWatchState = BaseSeriesWatchingState.GetState(SeriesWatchingStatus.ToWatch, _serviceProvider);
                await toWatchState.UpdateStateAsync(userId, seriesId, 0, 0);
                return SeriesWatchingStatus.ToWatch;
            }

            var seriesEpisodeIds = (series.Seasons ?? Enumerable.Empty<Season>())
                .SelectMany(season => season.Episodes ?? Enumerable.Empty<Episode>())
                .Select(episode => episode.Id)
                .ToList();

            // Get ONLY completed episode progress records for this series (filter at database level)
            var watchedEpisodeIds = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId
                          && ep.IsCompleted
                          && seriesEpisodeIds.Contains(ep.EpisodeId))
                .Select(ep => ep.EpisodeId)
                .Distinct()
                .ToListAsync();
            
            var watchedEpisodes = watchedEpisodeIds.Count;
            
            // Log any incomplete records for debugging (but don't use them in calculations)
            var incompleteRecords = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId
                          && !ep.IsCompleted
                          && seriesEpisodeIds.Contains(ep.EpisodeId))
                .Select(ep => ep.EpisodeId)
                .ToListAsync();
            
            if (incompleteRecords.Any())
            {
                _logger.LogWarning("SeriesWatchingStateService: Found {Count} incomplete episode progress records for UserId={UserId}, SeriesId={SeriesId}. EpisodeIds: {EpisodeIds}. These will be ignored.",
                    incompleteRecords.Count, userId, seriesId, 
                    string.Join(", ", incompleteRecords.Distinct()));
            }

            var currentStateEntity = await _context.SeriesWatchingStates
                .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);

            var currentStatus = currentStateEntity?.Status ?? SeriesWatchingStatus.ToWatch;
            
            // CRITICAL: If current status is Finished, check if user has a review
            // If they do, the series must remain Finished (cannot revert to InProgress)
            if (currentStatus == SeriesWatchingStatus.Finished)
            {
                var hasReview = await _context.Ratings
                    .AnyAsync(r => r.UserId == userId && r.SeriesId == seriesId);
                
                if (hasReview)
                {
                    _logger.LogInformation("Series {SeriesId} for User {UserId} is Finished and has a review. Keeping status as Finished even if EpisodeProgress suggests otherwise.",
                        seriesId, userId);
                    
                    // Ensure status remains Finished
                    var finishedState = BaseSeriesWatchingState.GetState(SeriesWatchingStatus.Finished, _serviceProvider);
                    var newStatus = await finishedState.UpdateStateAsync(userId, seriesId, totalEpisodes, watchedEpisodes);
                    return newStatus;
                }
            }
            
            var currentState = BaseSeriesWatchingState.GetState(currentStatus, _serviceProvider);
            var newStatusResult = await currentState.UpdateStateAsync(userId, seriesId, totalEpisodes, watchedEpisodes);

            return newStatusResult;
        }
    }
}
