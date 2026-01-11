using AutoMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;
using SeriLovers.API.Domain.Exceptions;
using SeriLovers.API.Models;

namespace SeriLovers.API.Domain.StateMachine
{
    /// <summary>
    /// Base class for all series watching states
    /// Each state inherits from this and overrides only the methods allowed for that state
    /// </summary>
    public abstract class BaseSeriesWatchingState
    {
        protected readonly IServiceProvider _serviceProvider;
        protected readonly ApplicationDbContext _context;
        protected readonly IMapper _mapper;
        protected readonly ILogger<BaseSeriesWatchingState> _logger;

        protected BaseSeriesWatchingState(
            IServiceProvider serviceProvider,
            ApplicationDbContext context,
            IMapper mapper,
            ILogger<BaseSeriesWatchingState> logger)
        {
            _serviceProvider = serviceProvider;
            _context = context;
            _mapper = mapper;
            _logger = logger;
        }

        /// <summary>
        /// Gets the current state name (ToWatch, InProgress, Finished)
        /// </summary>
        public abstract SeriesWatchingStatus StateName { get; }

        /// <summary>
        /// Updates the watching state based on watched episode count
        /// Override this in states that allow updates
        /// </summary>
        public virtual Task<SeriesWatchingStatus> UpdateStateAsync(int userId, int seriesId, int totalEpisodes, int watchedEpisodes)
        {
            return Task.FromException<SeriesWatchingStatus>(new UserException($"Updating state from {StateName} is not allowed"));
        }

        /// <summary>
        /// Validates that a review can be created (only allowed in Finished state)
        /// </summary>
        public virtual void ValidateReviewCreation()
        {
            throw new ReviewNotAllowedException(StateName);
        }

        /// <summary>
        /// Resolves the correct state instance based on state name using dependency injection
        /// </summary>
        public static BaseSeriesWatchingState GetState(SeriesWatchingStatus stateName, IServiceProvider serviceProvider)
        {
            return stateName switch
            {
                SeriesWatchingStatus.ToWatch => serviceProvider.GetRequiredService<ToWatchState>(),
                SeriesWatchingStatus.InProgress => serviceProvider.GetRequiredService<InProgressState>(),
                SeriesWatchingStatus.Finished => serviceProvider.GetRequiredService<FinishedState>(),
                _ => throw new UserException($"Unknown state: {stateName}")
            };
        }

        public static SeriesWatchingStatus CalculateState(int totalEpisodes, int watchedEpisodes)
        {
            if (watchedEpisodes <= 0)
            {
                return SeriesWatchingStatus.ToWatch;
            }

            if (watchedEpisodes >= totalEpisodes)
            {
                return SeriesWatchingStatus.Finished;
            }

            return SeriesWatchingStatus.InProgress;
        }

        /// <summary>
        /// Protected helper method for use in derived classes (same as CalculateState)
        /// </summary>
        protected static SeriesWatchingStatus CalculateStateFromProgress(int totalEpisodes, int watchedEpisodes)
        {
            return CalculateState(totalEpisodes, watchedEpisodes);
        }

        /// <summary>
        /// Persists the state to the database
        /// </summary>
        protected async Task PersistStateAsync(int userId, int seriesId, SeriesWatchingStatus status, int watchedEpisodes, int totalEpisodes)
        {
            var trackedEntity = _context.ChangeTracker.Entries<SeriesWatchingState>()
                .FirstOrDefault(e => e.Entity.UserId == userId && e.Entity.SeriesId == seriesId);

            SeriesWatchingState stateEntity;

            if (trackedEntity != null)
            {
                stateEntity = trackedEntity.Entity;
                stateEntity.Status = status;
                stateEntity.WatchedEpisodesCount = watchedEpisodes;
                stateEntity.TotalEpisodesCount = totalEpisodes;
                stateEntity.LastUpdated = DateTime.UtcNow;
            }
            else
            {
                var existingState = await _context.SeriesWatchingStates
                    .FirstOrDefaultAsync(s => s.UserId == userId && s.SeriesId == seriesId);

                if (existingState == null)
                {
                    stateEntity = new SeriesWatchingState
                    {
                        UserId = userId,
                        SeriesId = seriesId,
                        Status = status,
                        WatchedEpisodesCount = watchedEpisodes,
                        TotalEpisodesCount = totalEpisodes,
                        CreatedAt = DateTime.UtcNow,
                        LastUpdated = DateTime.UtcNow
                    };
                    _context.SeriesWatchingStates.Add(stateEntity);
                }
                else
                {
                    stateEntity = existingState;
                    stateEntity.Status = status;
                    stateEntity.WatchedEpisodesCount = watchedEpisodes;
                    stateEntity.TotalEpisodesCount = totalEpisodes;
                    stateEntity.LastUpdated = DateTime.UtcNow;
                    _context.SeriesWatchingStates.Update(stateEntity);
                }
            }

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to persist SeriesWatchingState. UserId={UserId}, SeriesId={SeriesId}, Status={Status}", userId, seriesId, status);
                throw;
            }
        }
    }
}
