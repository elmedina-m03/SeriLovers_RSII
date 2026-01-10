namespace SeriLovers.API.Domain.Exceptions
{
    /// <summary>
    /// Exception thrown when an invalid state transition is attempted
    /// </summary>
    public class InvalidStateTransitionException : Exception
    {
        public SeriesWatchingStatus CurrentState { get; }
        public SeriesWatchingStatus AttemptedState { get; }

        public InvalidStateTransitionException(
            SeriesWatchingStatus currentState, 
            SeriesWatchingStatus attemptedState)
            : base($"Invalid state transition from {currentState} to {attemptedState}")
        {
            CurrentState = currentState;
            AttemptedState = attemptedState;
        }
    }
}

