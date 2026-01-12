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
            var stateEntity = await _context.SeriesWatchingStates
                .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);

            if (stateEntity != null)
            {
                return stateEntity.Status;
            }

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

            // Get all episode progress records for this series (including non-completed ones for debugging)
            var allProgress = await _context.EpisodeProgresses
                .Where(ep => ep.UserId == userId
                          && seriesEpisodeIds.Contains(ep.EpisodeId))
                .ToListAsync();
            
            // Log any records with IsCompleted = false for debugging
            var incompleteRecords = allProgress.Where(ep => !ep.IsCompleted).ToList();
            if (incompleteRecords.Any())
            {
                _logger.LogWarning("SeriesWatchingStateService: Found {Count} incomplete episode progress records for UserId={UserId}, SeriesId={SeriesId}. EpisodeIds: {EpisodeIds}",
                    incompleteRecords.Count, userId, seriesId, 
                    string.Join(", ", incompleteRecords.Select(ep => ep.EpisodeId)));
            }
            
            // Only count completed episodes
            var watchedEpisodeIds = allProgress
                .Where(ep => ep.IsCompleted)
                .Select(ep => ep.EpisodeId)
                .Distinct()
                .ToList();
            
            var watchedEpisodes = watchedEpisodeIds.Count;

            var currentStateEntity = await _context.SeriesWatchingStates
                .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);

            var currentStatus = currentStateEntity?.Status ?? SeriesWatchingStatus.ToWatch;
            var currentState = BaseSeriesWatchingState.GetState(currentStatus, _serviceProvider);
            var newStatus = await currentState.UpdateStateAsync(userId, seriesId, totalEpisodes, watchedEpisodes);

            return newStatus;
        }
    }
}
