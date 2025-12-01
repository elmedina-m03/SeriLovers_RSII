using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Models;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Data
{
    /// <summary>
    /// Simple data seeder to add test episodes for existing series
    /// Run this once to populate episodes for testing
    /// </summary>
    public static class SeedData
    {
        public static async Task SeedEpisodesAsync(ApplicationDbContext context)
        {
            // Get all series that don't have seasons/episodes yet
            var seriesWithoutEpisodes = await context.Series
                .Where(s => !s.Seasons.Any())
                .Take(5) // Limit to first 5 series for testing
                .ToListAsync();

            foreach (var series in seriesWithoutEpisodes)
            {
                // Create Season 1 with 20 episodes
                var season = new Season
                {
                    SeriesId = series.Id,
                    SeasonNumber = 1,
                    Title = $"{series.Title} - Season 1",
                    Description = $"The first season of {series.Title}",
                    ReleaseDate = series.ReleaseDate,
                };

                context.Seasons.Add(season);
                await context.SaveChangesAsync();

                // Create 20 episodes for this season
                for (int i = 1; i <= 20; i++)
                {
                    var episode = new Episode
                    {
                        SeasonId = season.Id,
                        EpisodeNumber = i,
                        Title = $"Episode {i}",
                        Description = $"Episode {i} of {series.Title}",
                        AirDate = series.ReleaseDate.AddDays(i * 7), // Weekly episodes
                        DurationMinutes = 45,
                    };

                    context.Episodes.Add(episode);
                }
            }

            await context.SaveChangesAsync();
        }
    }
}

