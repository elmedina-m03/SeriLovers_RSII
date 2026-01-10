using SeriLovers.API.Domain.Exceptions;
using SeriLovers.API.Domain.StateMachine;

namespace SeriLovers.API.Domain
{
    [Obsolete("Use BaseSeriesWatchingState and concrete state classes")]
    public class SeriesWatchingStateMachine
    {
        private SeriesWatchingStatus _currentState;

        /// <summary>
        /// Gets the current state
        /// </summary>
        public SeriesWatchingStatus CurrentState => _currentState;

        /// <summary>
        /// Initializes a new instance of the state machine with the specified initial state
        /// </summary>
        public SeriesWatchingStateMachine(SeriesWatchingStatus initialState = SeriesWatchingStatus.ToWatch)
        {
            _currentState = initialState;
        }

        /// <summary>
        /// Transitions to InProgress state when the first episode is watched
        /// </summary>
        /// <exception cref="InvalidStateTransitionException">Thrown when transition is not allowed</exception>
        public void TransitionToInProgress()
        {
            if (_currentState != SeriesWatchingStatus.ToWatch)
            {
                throw new InvalidStateTransitionException(
                    _currentState, 
                    SeriesWatchingStatus.InProgress);
            }

            _currentState = SeriesWatchingStatus.InProgress;
        }

        /// <summary>
        /// Transitions to Finished state when all episodes are watched
        /// </summary>
        /// <exception cref="InvalidStateTransitionException">Thrown when transition is not allowed</exception>
        public void TransitionToFinished()
        {
            if (_currentState != SeriesWatchingStatus.InProgress)
            {
                throw new InvalidStateTransitionException(
                    _currentState, 
                    SeriesWatchingStatus.Finished);
            }

            _currentState = SeriesWatchingStatus.Finished;
        }

        /// <summary>
        /// Validates that a review can be created (only allowed in Finished state)
        /// </summary>
        /// <exception cref="ReviewNotAllowedException">Thrown when review creation is not allowed</exception>
        public void ValidateReviewCreation()
        {
            if (_currentState != SeriesWatchingStatus.Finished)
            {
                throw new ReviewNotAllowedException(_currentState);
            }
        }

        [Obsolete("Use BaseSeriesWatchingState.CalculateState() instead")]
        public static SeriesWatchingStatus CalculateState(int totalEpisodes, int watchedEpisodes)
        {
            return StateMachine.BaseSeriesWatchingState.CalculateState(totalEpisodes, watchedEpisodes);
        }

        /// <summary>
        /// Updates the state machine to the appropriate state based on watched episode counts
        /// </summary>
        /// <param name="totalEpisodes">Total number of episodes in the series</param>
        /// <param name="watchedEpisodes">Number of episodes watched</param>
        public void UpdateState(int totalEpisodes, int watchedEpisodes)
        {
            var targetState = CalculateState(totalEpisodes, watchedEpisodes);

            if (targetState == _currentState)
            {
                return;
            }

            switch (targetState)
            {
                case SeriesWatchingStatus.InProgress:
                    if (_currentState == SeriesWatchingStatus.ToWatch)
                    {
                        TransitionToInProgress();
                    }
                    else
                    {
                        _currentState = SeriesWatchingStatus.InProgress;
                    }
                    break;

                case SeriesWatchingStatus.Finished:
                    if (_currentState == SeriesWatchingStatus.InProgress)
                    {
                        TransitionToFinished();
                    }
                    else
                    {
                        _currentState = SeriesWatchingStatus.Finished;
                    }
                    break;

                case SeriesWatchingStatus.ToWatch:
                    _currentState = SeriesWatchingStatus.ToWatch;
                    break;
            }
        }
    }
}

