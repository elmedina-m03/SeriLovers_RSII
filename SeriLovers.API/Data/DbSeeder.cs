using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Data
{
    public class DbSeeder
    {
        private static readonly Random Random = new Random();

        private record SeriesSeedDefinition(
            string Title,
            string Description,
            DateTime ReleaseDate,
            string PrimaryGenre,
            double Rating,
            string[] Genres,
            (string FirstName, string LastName, string RoleName)[] Actors,
            int SeasonsToEnsure = 2);

        private static readonly string[] DefaultRoles = { "Admin", "User" };

        public static async Task SeedRolesAndUsersAsync(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager,
            RoleManager<IdentityRole<int>> roleManager)
        {
            await EnsureRolesAsync(roleManager);
            await EnsureAdminAssignedToFirstUserAsync(userManager);
        }

        private static async Task SeedFavoriteCharactersAsync(ApplicationDbContext context)
        {
            if (await context.FavoriteCharacters.AnyAsync())
            {
                return;
            }

            var userIds = await context.Users.Select(u => u.Id).ToListAsync();
            if (userIds.Count == 0)
            {
                return;
            }

            var favorites = new List<(string SeriesTitle, string ActorFirst, string ActorLast)>
            {
                ("Breaking Bad", "Bryan", "Cranston"),
                ("Game of Thrones", "Emilia", "Clarke"),
                ("Stranger Things", "Millie Bobby", "Brown")
            };

            foreach (var (seriesTitle, actorFirst, actorLast) in favorites)
            {
                var series = await context.Series.FirstOrDefaultAsync(s => s.Title == seriesTitle);
                if (series == null)
                {
                    continue;
                }

                var actor = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == actorFirst && a.LastName == actorLast);
                if (actor == null)
                {
                    continue;
                }

                foreach (var userId in userIds)
                {
                    var exists = await context.FavoriteCharacters.AnyAsync(fc =>
                        fc.UserId == userId && fc.SeriesId == series.Id && fc.ActorId == actor.Id);

                    if (!exists)
                    {
                        await context.FavoriteCharacters.AddAsync(new FavoriteCharacter
                        {
                            UserId = userId,
                            SeriesId = series.Id,
                            ActorId = actor.Id,
                            CreatedAt = DateTime.UtcNow
                        });
                    }
                }
            }
        }

        private static async Task SeedRecommendationLogsAsync(ApplicationDbContext context)
        {
            if (await context.RecommendationLogs.AnyAsync())
            {
                return;
            }

            var userIds = await context.Users.Select(u => u.Id).ToListAsync();
            if (userIds.Count == 0)
            {
                return;
            }

            var seriesList = await context.Series
                .AsNoTracking()
                .OrderByDescending(s => s.Rating)
                .Take(5)
                .Select(s => s.Id)
                .ToListAsync();

            if (seriesList.Count == 0)
            {
                return;
            }

            var random = new Random();

            foreach (var userId in userIds)
            {
                foreach (var seriesId in seriesList)
                {
                    var exists = await context.RecommendationLogs.AnyAsync(log =>
                        log.UserId == userId && log.SeriesId == seriesId);

                    if (!exists)
                    {
                        await context.RecommendationLogs.AddAsync(new RecommendationLog
                        {
                            UserId = userId,
                            SeriesId = seriesId,
                            RecommendedAt = DateTime.UtcNow.AddDays(-random.Next(1, 30)),
                            Watched = random.NextDouble() >= 0.5
                        });
                    }
                }
            }
        }

        public static async Task SeedGenresAsync(ApplicationDbContext context)
        {
            // Check if genres already exist
            if (await context.Genres.AnyAsync())
            {
                return; // Database already has genres, skip seeding
            }

            var genres = new List<Genre>
            {
                new Genre { Name = "Crime Drama" },
                new Genre { Name = "Fantasy Drama" },
                new Genre { Name = "Comedy" },
                new Genre { Name = "Sci-Fi Horror" },
                new Genre { Name = "Historical Drama" },
                new Genre { Name = "Drama" },
                new Genre { Name = "Thriller" },
                new Genre { Name = "Action" }
            };

            await context.Genres.AddRangeAsync(genres);
            await context.SaveChangesAsync();
        }

        public static async Task SeedActorsAsync(ApplicationDbContext context)
        {
            // Check if actors already exist
            if (await context.Actors.AnyAsync())
            {
                return; // Database already has actors, skip seeding
            }

            var actors = new List<Actor>
            {
                new Actor
                {
                    FirstName = "Bryan",
                    LastName = "Cranston",
                    DateOfBirth = new DateTime(1956, 3, 7),
                    Biography = "American actor known for his role as Walter White in Breaking Bad."
                },
                new Actor
                {
                    FirstName = "Aaron",
                    LastName = "Paul",
                    DateOfBirth = new DateTime(1979, 8, 27),
                    Biography = "American actor known for his role as Jesse Pinkman in Breaking Bad."
                },
                new Actor
                {
                    FirstName = "Emilia",
                    LastName = "Clarke",
                    DateOfBirth = new DateTime(1986, 10, 23),
                    Biography = "British actress known for her role as Daenerys Targaryen in Game of Thrones."
                },
                new Actor
                {
                    FirstName = "Kit",
                    LastName = "Harington",
                    DateOfBirth = new DateTime(1986, 12, 26),
                    Biography = "British actor known for his role as Jon Snow in Game of Thrones."
                },
                new Actor
                {
                    FirstName = "Steve",
                    LastName = "Carell",
                    DateOfBirth = new DateTime(1962, 8, 16),
                    Biography = "American actor and comedian known for his role as Michael Scott in The Office."
                },
                new Actor
                {
                    FirstName = "John",
                    LastName = "Krasinski",
                    DateOfBirth = new DateTime(1979, 10, 20),
                    Biography = "American actor known for his role as Jim Halpert in The Office."
                },
                new Actor
                {
                    FirstName = "Millie Bobby",
                    LastName = "Brown",
                    DateOfBirth = new DateTime(2004, 2, 19),
                    Biography = "British actress known for her role as Eleven in Stranger Things."
                },
                new Actor
                {
                    FirstName = "David",
                    LastName = "Harbour",
                    DateOfBirth = new DateTime(1975, 4, 10),
                    Biography = "American actor known for his role as Jim Hopper in Stranger Things."
                },
                new Actor
                {
                    FirstName = "Claire",
                    LastName = "Foy",
                    DateOfBirth = new DateTime(1984, 4, 16),
                    Biography = "British actress known for her role as Queen Elizabeth II in The Crown."
                },
                new Actor
                {
                    FirstName = "Matt",
                    LastName = "Smith",
                    DateOfBirth = new DateTime(1982, 10, 28),
                    Biography = "British actor known for his role as Prince Philip in The Crown."
                },
                new Actor
                {
                    FirstName = "Jennifer",
                    LastName = "Aniston",
                    DateOfBirth = new DateTime(1969, 2, 11),
                    Biography = "American actress known for her role as Rachel Green in Friends."
                },
                new Actor
                {
                    FirstName = "Matthew",
                    LastName = "Perry",
                    DateOfBirth = new DateTime(1969, 8, 19),
                    Biography = "American actor known for his role as Chandler Bing in Friends."
                }
            };

            await context.Actors.AddRangeAsync(actors);
            await context.SaveChangesAsync();
        }

        public static async Task SeedSeriesAsync(ApplicationDbContext context)
        {
            var seriesSeeds = new[]
            {
                new SeriesSeedDefinition(
                    "Breaking Bad",
                    "A high school chemistry teacher turned methamphetamine manufacturer partners with a former student to secure his family's future.",
                    new DateTime(2008, 1, 20),
                    "Crime Drama",
                    9.5,
                    new[] { "Crime Drama", "Drama" },
                    new[]
                    {
                        ("Bryan", "Cranston", "Walter White"),
                        ("Aaron", "Paul", "Jesse Pinkman")
                    }),
                new SeriesSeedDefinition(
                    "Game of Thrones",
                    "Nine noble families fight for control over the lands of Westeros, while an ancient enemy returns after being dormant for millennia.",
                    new DateTime(2011, 4, 17),
                    "Fantasy Drama",
                    9.3,
                    new[] { "Fantasy Drama", "Drama" },
                    new[]
                    {
                        ("Emilia", "Clarke", "Daenerys Targaryen"),
                        ("Kit", "Harington", "Jon Snow")
                    }),
                new SeriesSeedDefinition(
                    "The Office",
                    "A mockumentary on a group of typical office workers, where the workday consists of ego clashes, inappropriate behavior, and tedium.",
                    new DateTime(2005, 3, 24),
                    "Comedy",
                    8.9,
                    new[] { "Comedy" },
                    new[]
                    {
                        ("Steve", "Carell", "Michael Scott"),
                        ("John", "Krasinski", "Jim Halpert")
                    }),
                new SeriesSeedDefinition(
                    "Stranger Things",
                    "When a young boy vanishes, a small town uncovers a mystery involving secret experiments, terrifying supernatural forces and one strange little girl.",
                    new DateTime(2016, 7, 15),
                    "Sci-Fi Horror",
                    8.7,
                    new[] { "Sci-Fi Horror", "Drama" },
                    new[]
                    {
                        ("Millie Bobby", "Brown", "Eleven"),
                        ("David", "Harbour", "Jim Hopper")
                    }),
                new SeriesSeedDefinition(
                    "The Crown",
                    "Follows the political rivalries and romance of Queen Elizabeth II's reign and the events that shaped the second half of the 20th century.",
                    new DateTime(2016, 11, 4),
                    "Historical Drama",
                    8.6,
                    new[] { "Historical Drama", "Drama" },
                    new[]
                    {
                        ("Claire", "Foy", "Queen Elizabeth II"),
                        ("Matt", "Smith", "Prince Philip")
                    }),
                new SeriesSeedDefinition(
                    "Friends",
                    "Follows the personal and professional lives of six twenty to thirty-something-year-old friends living in Manhattan.",
                    new DateTime(1994, 9, 22),
                    "Comedy",
                    8.9,
                    new[] { "Comedy", "Drama" },
                    new[]
                    {
                        ("Jennifer", "Aniston", "Rachel Green"),
                        ("Matthew", "Perry", "Chandler Bing")
                    })
            };

            var genres = await context.Genres.ToDictionaryAsync(g => g.Name, StringComparer.OrdinalIgnoreCase);
            var actors = await context.Actors.ToDictionaryAsync(
                a => $"{a.FirstName} {a.LastName}",
                StringComparer.OrdinalIgnoreCase);

            foreach (var seed in seriesSeeds)
            {
                var series = await context.Series
                    .Include(s => s.Seasons!)
                        .ThenInclude(season => season.Episodes)
                    .Include(s => s.SeriesGenres)
                    .Include(s => s.SeriesActors)
                    .FirstOrDefaultAsync(s => s.Title == seed.Title);

                if (series == null)
                {
                    series = new Series
                    {
                        Title = seed.Title,
                        Description = seed.Description,
                        ReleaseDate = seed.ReleaseDate,
                        Genre = seed.PrimaryGenre,
                        Rating = seed.Rating
                    };

                    await context.Series.AddAsync(series);
                    await context.SaveChangesAsync();
                }
                else
                {
                    series.Description = seed.Description;
                    series.ReleaseDate = seed.ReleaseDate;
                    series.Genre = seed.PrimaryGenre;
                    series.Rating = seed.Rating;
                }

                foreach (var genreName in seed.Genres.Distinct(StringComparer.OrdinalIgnoreCase))
                {
                    if (!genres.TryGetValue(genreName, out var genre))
                    {
                        continue;
                    }

                    var genreExists = await context.SeriesGenres
                        .AnyAsync(sg => sg.SeriesId == series.Id && sg.GenreId == genre.Id);

                    if (!genreExists)
                    {
                        var seriesGenre = new SeriesGenre
                        {
                            SeriesId = series.Id,
                            GenreId = genre.Id
                        };

                        await context.SeriesGenres.AddAsync(seriesGenre);

                        series.SeriesGenres ??= new List<SeriesGenre>();
                        series.SeriesGenres.Add(seriesGenre);
                    }
                    else if (series.SeriesGenres?.All(sg => sg.GenreId != genre.Id) == true)
                    {
                        series.SeriesGenres.Add(new SeriesGenre
                        {
                            SeriesId = series.Id,
                            GenreId = genre.Id,
                            Genre = genre
                        });
                    }
                }

                foreach (var (firstName, lastName, roleName) in seed.Actors)
                {
                    var key = $"{firstName} {lastName}";
                    if (!actors.TryGetValue(key, out var actor))
                    {
                        continue;
                    }

                    var actorExists = await context.SeriesActors
                        .AnyAsync(sa => sa.SeriesId == series.Id && sa.ActorId == actor.Id);

                    if (!actorExists)
                    {
                        var seriesActor = new SeriesActor
                        {
                            SeriesId = series.Id,
                            ActorId = actor.Id,
                            RoleName = roleName
                        };

                        await context.SeriesActors.AddAsync(seriesActor);

                        series.SeriesActors ??= new List<SeriesActor>();
                        series.SeriesActors.Add(seriesActor);
                    }
                    else if (series.SeriesActors?.All(sa => sa.ActorId != actor.Id) == true)
                    {
                        series.SeriesActors.Add(new SeriesActor
                        {
                            SeriesId = series.Id,
                            ActorId = actor.Id,
                            RoleName = roleName,
                            Actor = actor
                        });
                    }
                }

                await EnsureSeasonsWithEpisodesAsync(context, series, seed.SeasonsToEnsure, 3, 5);
            }

            if (context.ChangeTracker.HasChanges())
            {
                await context.SaveChangesAsync();
            }
        }

        private static async Task EnsureSeasonsWithEpisodesAsync(
            ApplicationDbContext context,
            Series series,
            int minSeasonCount,
            int minEpisodesPerSeason,
            int maxEpisodesPerSeason)
        {
            var seasons = await context.Seasons
                .Include(season => season.Episodes)
                .Where(season => season.SeriesId == series.Id)
                .ToListAsync();

            if (seasons.Count < minSeasonCount)
            {
                for (int newSeasonNumber = seasons.Count + 1; newSeasonNumber <= minSeasonCount; newSeasonNumber++)
                {
                    var releaseDate = series.ReleaseDate.AddYears(newSeasonNumber - 1);
                    var newSeason = new Season
                    {
                        SeriesId = series.Id,
                        SeasonNumber = newSeasonNumber,
                        Title = $"{series.Title} - Season {newSeasonNumber}",
                        Description = $"Season {newSeasonNumber} of {series.Title}",
                        ReleaseDate = releaseDate,
                        Episodes = new List<Episode>()
                    };

                    await context.Seasons.AddAsync(newSeason);
                    seasons.Add(newSeason);
                }
            }

            for (int seasonNumber = 1; seasonNumber <= minSeasonCount; seasonNumber++)
            {
                var season = seasons.FirstOrDefault(s => s.SeasonNumber == seasonNumber);

                if (season == null)
                {
                    var releaseDate = series.ReleaseDate.AddYears(seasonNumber - 1);
                    season = new Season
                    {
                        SeriesId = series.Id,
                        SeasonNumber = seasonNumber,
                        Title = $"{series.Title} - Season {seasonNumber}",
                        Description = $"Season {seasonNumber} of {series.Title}",
                        ReleaseDate = releaseDate,
                        Episodes = new List<Episode>()
                    };

                    await context.Seasons.AddAsync(season);
                    seasons.Add(season);
                }

                season.Episodes ??= new List<Episode>();

                var desiredEpisodeCount = Random.Next(minEpisodesPerSeason, maxEpisodesPerSeason + 1);

                if (season.Episodes.Count > maxEpisodesPerSeason)
                {
                    var episodesToRemove = season.Episodes
                        .OrderByDescending(e => e.EpisodeNumber)
                        .Skip(maxEpisodesPerSeason)
                        .ToList();

                    if (episodesToRemove.Count > 0)
                    {
                        context.Episodes.RemoveRange(episodesToRemove);
                        foreach (var episode in episodesToRemove)
                        {
                            season.Episodes.Remove(episode);
                        }
                    }
                }

                if (season.Episodes.Count < minEpisodesPerSeason)
                {
                    desiredEpisodeCount = Math.Max(desiredEpisodeCount, minEpisodesPerSeason);
                }

                var releaseBase = season.ReleaseDate ?? series.ReleaseDate.AddYears(seasonNumber - 1);

                for (int episodeNumber = 1; episodeNumber <= desiredEpisodeCount; episodeNumber++)
                {
                    if (season.Episodes.Any(e => e.EpisodeNumber == episodeNumber))
                    {
                        continue;
                    }

                    var episode = new Episode
                    {
                        EpisodeNumber = episodeNumber,
                        Title = $"{series.Title} S{seasonNumber:D2}E{episodeNumber:D2}",
                        Description = $"Episode {episodeNumber} of season {seasonNumber} for {series.Title}.",
                        AirDate = releaseBase.AddDays(7 * (episodeNumber - 1)),
                        DurationMinutes = 45,
                        Rating = null
                    };

                    if (season.Id == 0)
                    {
                        season.Episodes.Add(episode);
                    }
                    else
                    {
                        episode.SeasonId = season.Id;
                        await context.Episodes.AddAsync(episode);
                    }
                }

                if (season.Episodes.Count > desiredEpisodeCount)
                {
                    var episodesToRemove = season.Episodes
                        .OrderByDescending(e => e.EpisodeNumber)
                        .Skip(desiredEpisodeCount)
                        .ToList();

                    if (episodesToRemove.Count > 0)
                    {
                        context.Episodes.RemoveRange(episodesToRemove);
                        foreach (var episode in episodesToRemove)
                        {
                            season.Episodes.Remove(episode);
                        }
                    }
                }
            }

            await context.SaveChangesAsync();
        }

        private static async Task EnsureRolesAsync(RoleManager<IdentityRole<int>> roleManager)
        {
            foreach (var roleName in DefaultRoles)
            {
                if (!await roleManager.RoleExistsAsync(roleName))
                {
                    var role = new IdentityRole<int>
                    {
                        Name = roleName,
                        NormalizedName = roleName.ToUpperInvariant()
                    };

                    await roleManager.CreateAsync(role);
                }
            }
        }

        private static async Task EnsureAdminAssignedToFirstUserAsync(UserManager<ApplicationUser> userManager)
        {
            var firstUser = await userManager.Users
                .OrderBy(u => u.Id)
                .FirstOrDefaultAsync();

            if (firstUser == null)
            {
                return;
            }

            if (!await userManager.IsInRoleAsync(firstUser, "Admin"))
            {
                await userManager.AddToRoleAsync(firstUser, "Admin");
            }
        }

        public static async Task Seed(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();

            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole<int>>>();

            // Seed roles i korisnika
            await SeedRolesAndUsersAsync(context, userManager, roleManager);

            // Seed genres
            await SeedGenresAsync(context);

            // Seed actors
            await SeedActorsAsync(context);

            // Seed series
            await SeedSeriesAsync(context);

            await SeedFavoriteCharactersAsync(context);
            await SeedRecommendationLogsAsync(context);
        }
    }
}

