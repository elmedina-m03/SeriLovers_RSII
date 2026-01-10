using SeriLovers.API.Domain;
using SeriLovers.API.Domain.Exceptions;
using Xunit;

namespace SeriLovers.API.Tests
{
    public class SeriesWatchingStateMachineTests
    {
        [Fact]
        public void Constructor_WithDefaultState_InitializesToToWatch()
        {
            // Arrange & Act
            var stateMachine = new SeriesWatchingStateMachine();

            // Assert
            Assert.Equal(SeriesWatchingStatus.ToWatch, stateMachine.CurrentState);
        }

        [Fact]
        public void Constructor_WithInitialState_SetsCorrectState()
        {
            // Arrange & Act
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.InProgress);

            // Assert
            Assert.Equal(SeriesWatchingStatus.InProgress, stateMachine.CurrentState);
        }

        [Fact]
        public void TransitionToInProgress_FromToWatch_TransitionsSuccessfully()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.ToWatch);

            // Act
            stateMachine.TransitionToInProgress();

            // Assert
            Assert.Equal(SeriesWatchingStatus.InProgress, stateMachine.CurrentState);
        }

        [Fact]
        public void TransitionToInProgress_FromInProgress_ThrowsException()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.InProgress);

            // Act & Assert
            var exception = Assert.Throws<InvalidStateTransitionException>(
                () => stateMachine.TransitionToInProgress());
            
            Assert.Equal(SeriesWatchingStatus.InProgress, exception.CurrentState);
            Assert.Equal(SeriesWatchingStatus.InProgress, exception.AttemptedState);
        }

        [Fact]
        public void TransitionToInProgress_FromFinished_ThrowsException()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.Finished);

            // Act & Assert
            var exception = Assert.Throws<InvalidStateTransitionException>(
                () => stateMachine.TransitionToInProgress());
            
            Assert.Equal(SeriesWatchingStatus.Finished, exception.CurrentState);
            Assert.Equal(SeriesWatchingStatus.InProgress, exception.AttemptedState);
        }

        [Fact]
        public void TransitionToFinished_FromInProgress_TransitionsSuccessfully()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.InProgress);

            // Act
            stateMachine.TransitionToFinished();

            // Assert
            Assert.Equal(SeriesWatchingStatus.Finished, stateMachine.CurrentState);
        }

        [Fact]
        public void TransitionToFinished_FromToWatch_ThrowsException()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.ToWatch);

            // Act & Assert
            var exception = Assert.Throws<InvalidStateTransitionException>(
                () => stateMachine.TransitionToFinished());
            
            Assert.Equal(SeriesWatchingStatus.ToWatch, exception.CurrentState);
            Assert.Equal(SeriesWatchingStatus.Finished, exception.AttemptedState);
        }

        [Fact]
        public void TransitionToFinished_FromFinished_ThrowsException()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.Finished);

            // Act & Assert
            var exception = Assert.Throws<InvalidStateTransitionException>(
                () => stateMachine.TransitionToFinished());
            
            Assert.Equal(SeriesWatchingStatus.Finished, exception.CurrentState);
            Assert.Equal(SeriesWatchingStatus.Finished, exception.AttemptedState);
        }

        [Fact]
        public void ValidateReviewCreation_InFinishedState_DoesNotThrow()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.Finished);

            // Act & Assert
            stateMachine.ValidateReviewCreation(); // Should not throw
        }

        [Fact]
        public void ValidateReviewCreation_InToWatchState_ThrowsException()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.ToWatch);

            // Act & Assert
            var exception = Assert.Throws<ReviewNotAllowedException>(
                () => stateMachine.ValidateReviewCreation());
            
            Assert.Equal(SeriesWatchingStatus.ToWatch, exception.CurrentState);
        }

        [Fact]
        public void ValidateReviewCreation_InInProgressState_ThrowsException()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.InProgress);

            // Act & Assert
            var exception = Assert.Throws<ReviewNotAllowedException>(
                () => stateMachine.ValidateReviewCreation());
            
            Assert.Equal(SeriesWatchingStatus.InProgress, exception.CurrentState);
        }

        [Theory]
        [InlineData(0, 0, SeriesWatchingStatus.ToWatch)]
        [InlineData(10, 0, SeriesWatchingStatus.ToWatch)]
        [InlineData(10, 1, SeriesWatchingStatus.InProgress)]
        [InlineData(10, 5, SeriesWatchingStatus.InProgress)]
        [InlineData(10, 9, SeriesWatchingStatus.InProgress)]
        [InlineData(10, 10, SeriesWatchingStatus.Finished)]
        [InlineData(10, 15, SeriesWatchingStatus.Finished)] // Edge case: more watched than total
        public void CalculateState_WithVariousInputs_ReturnsCorrectState(
            int totalEpisodes, 
            int watchedEpisodes, 
            SeriesWatchingStatus expectedState)
        {
            // Act
            var result = SeriesWatchingStateMachine.CalculateState(totalEpisodes, watchedEpisodes);

            // Assert
            Assert.Equal(expectedState, result);
        }

        [Fact]
        public void UpdateState_FromToWatchToInProgress_TransitionsCorrectly()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.ToWatch);

            // Act
            stateMachine.UpdateState(10, 1);

            // Assert
            Assert.Equal(SeriesWatchingStatus.InProgress, stateMachine.CurrentState);
        }

        [Fact]
        public void UpdateState_FromInProgressToFinished_TransitionsCorrectly()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.InProgress);

            // Act
            stateMachine.UpdateState(10, 10);

            // Assert
            Assert.Equal(SeriesWatchingStatus.Finished, stateMachine.CurrentState);
        }

        [Fact]
        public void UpdateState_FromToWatchToFinished_TransitionsCorrectly()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.ToWatch);

            // Act
            stateMachine.UpdateState(10, 10);

            // Assert
            Assert.Equal(SeriesWatchingStatus.Finished, stateMachine.CurrentState);
        }

        [Fact]
        public void UpdateState_FromFinishedToInProgress_AllowsBackwardTransition()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.Finished);

            // Act
            stateMachine.UpdateState(10, 5);

            // Assert
            Assert.Equal(SeriesWatchingStatus.InProgress, stateMachine.CurrentState);
        }

        [Fact]
        public void UpdateState_FromInProgressToToWatch_AllowsBackwardTransition()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.InProgress);

            // Act
            stateMachine.UpdateState(10, 0);

            // Assert
            Assert.Equal(SeriesWatchingStatus.ToWatch, stateMachine.CurrentState);
        }

        [Fact]
        public void UpdateState_NoChangeInState_DoesNotModifyState()
        {
            // Arrange
            var stateMachine = new SeriesWatchingStateMachine(SeriesWatchingStatus.InProgress);

            // Act
            stateMachine.UpdateState(10, 5);

            // Assert
            Assert.Equal(SeriesWatchingStatus.InProgress, stateMachine.CurrentState);
        }
    }
}

