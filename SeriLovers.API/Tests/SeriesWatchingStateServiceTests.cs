using Microsoft.EntityFrameworkCore;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using SeriLovers.API.Data;
using SeriLovers.API.Domain;
using SeriLovers.API.Domain.Exceptions;
using SeriLovers.API.Models;
using SeriLovers.API.Services;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Tests
{
    [TestClass]
    public class SeriesWatchingStateServiceTests
    {
        private ApplicationDbContext _context;
        private SeriesWatchingStateService _service;

        [TestInitialize]
        public void Setup()
        {
            var options = new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            _context = new ApplicationDbContext(options);
            var serviceProvider = new ServiceCollection()
                .AddScoped<ToWatchState>()
                .AddScoped<InProgressState>()
                .AddScoped<FinishedState>()
                .AddAutoMapper(typeof(AppMappingProfile))
                .BuildServiceProvider();
            
            var logger = new LoggerFactory().CreateLogger<SeriesWatchingStateService>();
            var mapper = serviceProvider.GetRequiredService<IMapper>();
            _service = new SeriesWatchingStateService(_context, logger, serviceProvider, mapper);
        }

        [TestCleanup]
        public void Cleanup()
        {
            _context?.Dispose();
        }

        [TestMethod]
        public async Task GetStatusAsync_NoEpisodes_ReturnsToWatch()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            await _context.SaveChangesAsync();

            // Act
            var status = await _service.GetStatusAsync(user.Id, series.Id);

            // Assert
            Assert.AreEqual(SeriesWatchingStatus.ToWatch, status);
        }

        [TestMethod]
        public async Task GetStatusAsync_NoWatchedEpisodes_ReturnsToWatch()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            CreateTestEpisode(season.Id);
            CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Act
            var status = await _service.GetStatusAsync(user.Id, series.Id);

            // Assert
            Assert.AreEqual(SeriesWatchingStatus.ToWatch, status);
        }

        [TestMethod]
        public async Task GetStatusAsync_SomeEpisodesWatched_ReturnsInProgress()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            var episode1 = CreateTestEpisode(season.Id);
            var episode2 = CreateTestEpisode(season.Id);
            var episode3 = CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Mark one episode as watched
            _context.EpisodeProgresses.Add(new EpisodeProgress
            {
                UserId = user.Id,
                EpisodeId = episode1.Id,
                IsCompleted = true,
                WatchedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            // Act
            var status = await _service.GetStatusAsync(user.Id, series.Id);

            // Assert
            Assert.AreEqual(SeriesWatchingStatus.InProgress, status);
        }

        [TestMethod]
        public async Task GetStatusAsync_AllEpisodesWatched_ReturnsFinished()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            var episode1 = CreateTestEpisode(season.Id);
            var episode2 = CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Mark all episodes as watched
            _context.EpisodeProgresses.Add(new EpisodeProgress
            {
                UserId = user.Id,
                EpisodeId = episode1.Id,
                IsCompleted = true,
                WatchedAt = DateTime.UtcNow
            });
            _context.EpisodeProgresses.Add(new EpisodeProgress
            {
                UserId = user.Id,
                EpisodeId = episode2.Id,
                IsCompleted = true,
                WatchedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            // Act
            var status = await _service.GetStatusAsync(user.Id, series.Id);

            // Assert
            Assert.AreEqual(SeriesWatchingStatus.Finished, status);
        }

        [TestMethod]
        public async Task UpdateStatusAsync_CreatesNewStateEntity()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            var episode = CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Act
            var status = await _service.UpdateStatusAsync(user.Id, series.Id);

            // Assert
            Assert.AreEqual(SeriesWatchingStatus.ToWatch, status);
            var stateEntity = await _context.SeriesWatchingStates
                .FirstOrDefaultAsync(s => s.UserId == user.Id && s.SeriesId == series.Id);
            Assert.IsNotNull(stateEntity);
            Assert.AreEqual(SeriesWatchingStatus.ToWatch, stateEntity.Status);
            Assert.AreEqual(0, stateEntity.WatchedEpisodesCount);
            Assert.AreEqual(1, stateEntity.TotalEpisodesCount);
        }

        [TestMethod]
        public async Task UpdateStatusAsync_UpdatesExistingStateEntity()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            var episode1 = CreateTestEpisode(season.Id);
            var episode2 = CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Create initial state
            await _service.UpdateStatusAsync(user.Id, series.Id);

            // Mark one episode as watched
            _context.EpisodeProgresses.Add(new EpisodeProgress
            {
                UserId = user.Id,
                EpisodeId = episode1.Id,
                IsCompleted = true,
                WatchedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            // Act
            var status = await _service.UpdateStatusAsync(user.Id, series.Id);

            // Assert
            Assert.AreEqual(SeriesWatchingStatus.InProgress, status);
            var stateEntity = await _context.SeriesWatchingStates
                .FirstOrDefaultAsync(s => s.UserId == user.Id && s.SeriesId == series.Id);
            Assert.IsNotNull(stateEntity);
            Assert.AreEqual(SeriesWatchingStatus.InProgress, stateEntity.Status);
            Assert.AreEqual(1, stateEntity.WatchedEpisodesCount);
            Assert.AreEqual(2, stateEntity.TotalEpisodesCount);
        }

        [TestMethod]
        public async Task ValidateReviewCreationAsync_FinishedState_DoesNotThrow()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            var episode = CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Mark episode as watched
            _context.EpisodeProgresses.Add(new EpisodeProgress
            {
                UserId = user.Id,
                EpisodeId = episode.Id,
                IsCompleted = true,
                WatchedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            // Act & Assert
            await _service.ValidateReviewCreationAsync(user.Id, series.Id);
            // Should not throw
        }

        [TestMethod]
        [ExpectedException(typeof(ReviewNotAllowedException))]
        public async Task ValidateReviewCreationAsync_InProgressState_ThrowsException()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            var episode1 = CreateTestEpisode(season.Id);
            var episode2 = CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Mark one episode as watched (InProgress state)
            _context.EpisodeProgresses.Add(new EpisodeProgress
            {
                UserId = user.Id,
                EpisodeId = episode1.Id,
                IsCompleted = true,
                WatchedAt = DateTime.UtcNow
            });
            await _context.SaveChangesAsync();

            // Act
            await _service.ValidateReviewCreationAsync(user.Id, series.Id);
        }

        [TestMethod]
        [ExpectedException(typeof(ReviewNotAllowedException))]
        public async Task ValidateReviewCreationAsync_ToWatchState_ThrowsException()
        {
            // Arrange
            var user = CreateTestUser();
            var series = CreateTestSeries();
            var season = CreateTestSeason(series.Id);
            var episode = CreateTestEpisode(season.Id);
            await _context.SaveChangesAsync();

            // Act
            await _service.ValidateReviewCreationAsync(user.Id, series.Id);
        }

        [TestMethod]
        [ExpectedException(typeof(ArgumentException))]
        public async Task GetStatusAsync_InvalidSeriesId_ThrowsException()
        {
            // Arrange
            var user = CreateTestUser();
            await _context.SaveChangesAsync();

            // Act
            await _service.GetStatusAsync(user.Id, 999);
        }

        private ApplicationUser CreateTestUser()
        {
            var user = new ApplicationUser
            {
                UserName = $"testuser_{Guid.NewGuid()}",
                Email = $"test_{Guid.NewGuid()}@test.com",
                EmailConfirmed = true
            };
            _context.Users.Add(user);
            return user;
        }

        private Series CreateTestSeries()
        {
            var series = new Series
            {
                Title = "Test Series",
                Description = "Test Description",
                ReleaseDate = DateTime.UtcNow,
                Rating = 8.5
            };
            _context.Series.Add(series);
            return series;
        }

        private Season CreateTestSeason(int seriesId)
        {
            var season = new Season
            {
                SeriesId = seriesId,
                SeasonNumber = 1,
                Title = "Season 1"
            };
            _context.Seasons.Add(season);
            return season;
        }

        private Episode CreateTestEpisode(int seasonId)
        {
            var episode = new Episode
            {
                SeasonId = seasonId,
                EpisodeNumber = _context.Episodes.Count(e => e.SeasonId == seasonId) + 1,
                Title = $"Episode {_context.Episodes.Count(e => e.SeasonId == seasonId) + 1}"
            };
            _context.Episodes.Add(episode);
            return episode;
        }
    }
}

