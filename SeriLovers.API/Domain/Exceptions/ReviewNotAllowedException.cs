using SeriLovers.API.Domain;

namespace SeriLovers.API.Domain.Exceptions
{
    /// <summary>
    /// Exception thrown when attempting to create a review for a series that is not in Finished state
    /// </summary>
    public class ReviewNotAllowedException : Exception
    {
        public SeriesWatchingStatus CurrentState { get; }

        public ReviewNotAllowedException(SeriesWatchingStatus currentState)
            : base($"Review creation is not allowed. Series must be in Finished state, but current state is {currentState}")
        {
            CurrentState = currentState;
        }
    }
}

