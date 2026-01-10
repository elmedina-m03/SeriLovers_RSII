using System.Threading.Tasks;

namespace SeriLovers.API.Domain
{
    /// <summary>
    /// Service interface for managing series watching state
    /// </summary>
    public interface ISeriesWatchingStateService
    {
        /// <summary>
        /// Gets the current watching status for a user and series
        /// </summary>
        /// <param name="userId">The user ID</param>
        /// <param name="seriesId">The series ID</param>
        /// <returns>The current watching status</returns>
        Task<SeriesWatchingStatus> GetStatusAsync(int userId, int seriesId);

        /// <summary>
        /// Validates that a review can be created for the series
        /// </summary>
        /// <param name="userId">The user ID</param>
        /// <param name="seriesId">The series ID</param>
        /// <exception cref="Exceptions.ReviewNotAllowedException">Thrown when review creation is not allowed</exception>
        Task ValidateReviewCreationAsync(int userId, int seriesId);

        /// <summary>
        /// Updates the watching status for a user and series based on watched episodes
        /// This method ensures that a SeriesWatchingState entity exists (creates if not exists) and then applies state transitions
        /// </summary>
        /// <param name="userId">The user ID</param>
        /// <param name="seriesId">The series ID</param>
        /// <returns>The updated watching status</returns>
        Task<SeriesWatchingStatus> UpdateStatusAsync(int userId, int seriesId);
    }
}

