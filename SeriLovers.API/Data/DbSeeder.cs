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
                    .AsSplitQuery()
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

            // Add simple test data
            await SeedTestUsersAsync(userManager);
            await SeedTestActorsAsync(context);
            await SeedTestSeriesAsync(context);
            await SeedTestRatingsAsync(context);
            await SeedTestWatchlistsAsync(context);

            // Seed challenges
            await SeedChallengesAsync(context);

            // Seed challenge progress
            await SeedChallengeProgressAsync(context);

            // Seed dummy users (testuser1..testuser8@gmail.com)
            await SeedDummyUsersAsync(userManager);

            // Seed ratings and watchlists
            await SeedRatingsAndWatchlistsAsync(context);

            // Seed viewing events for monthly watching statistics
            await SeedViewingEventsAsync(context);

            // Seed dummy users with activity for statistics
            await SeedDummyUsersWithActivityAsync(context, userManager);
        }

        /// <summary>
        /// Seeds 10 dummy users with ratings and watchlist entries across different months
        /// to populate monthly statistics and top-rated series data
        /// </summary>
        private static async Task SeedDummyUsersWithActivityAsync(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            // Check if dummy users already exist
            if (await context.Users.AnyAsync(u => u.Email != null && u.Email.StartsWith("dummyuser")))
            {
                return; // Already seeded
            }

            var series = await context.Series.Take(10).ToListAsync();
            if (series.Count == 0)
            {
                return; // No series to add activity for
            }

            var users = new List<ApplicationUser>();
            var ratings = new List<Rating>();
            var watchlists = new List<Watchlist>();

            // Create 10 dummy users
            for (int i = 1; i <= 10; i++)
            {
                var email = $"dummyuser{i}@test.com";
                if (await userManager.FindByEmailAsync(email) == null)
                {
                    var user = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        EmailConfirmed = true,
                        DateCreated = DateTime.UtcNow.AddDays(-Random.Next(1, 90)) // Random creation date
                    };
                    var result = await userManager.CreateAsync(user, "Dummy123!");
                    if (result.Succeeded)
                    {
                        await userManager.AddToRoleAsync(user, "User");
                        users.Add(user);
                    }
                }
            }

            await context.SaveChangesAsync();

            // Get the created users
            var createdUsers = await context.Users
                .Where(u => u.Email != null && u.Email.StartsWith("dummyuser"))
                .ToListAsync();

            if (createdUsers.Count == 0 || series.Count == 0)
            {
                return;
            }

            // Generate activity across last 12 months
            var now = DateTime.UtcNow;
            var months = Enumerable.Range(0, 12)
                .Select(m => now.AddMonths(-m))
                .ToList();

            foreach (var user in createdUsers)
            {
                // Each user rates and adds to watchlist 3-5 random series
                var userSeries = series.OrderBy(x => Random.Next()).Take(Random.Next(3, 6)).ToList();

                foreach (var s in userSeries)
                {
                    // Random month from last 12 months
                    var activityMonth = months[Random.Next(months.Count)];
                    var activityDate = activityMonth.AddDays(Random.Next(0, 28)); // Random day in month

                    // Add rating if not exists
                    if (!await context.Ratings.AnyAsync(r => r.UserId == user.Id && r.SeriesId == s.Id))
                    {
                        ratings.Add(new Rating
                        {
                            UserId = user.Id,
                            SeriesId = s.Id,
                            Score = Random.Next(5, 11), // Rating between 5-10
                            CreatedAt = activityDate
                        });
                    }

                    // Add to watchlist if not exists
                    if (!await context.Watchlists.AnyAsync(w => w.UserId == user.Id && w.SeriesId == s.Id))
                    {
                        watchlists.Add(new Watchlist
                        {
                            UserId = user.Id,
                            SeriesId = s.Id,
                            AddedAt = activityDate
                        });
                    }
                }
            }

            // Bulk insert ratings and watchlists
            if (ratings.Any())
            {
                await context.Ratings.AddRangeAsync(ratings);
            }

            if (watchlists.Any())
            {
                await context.Watchlists.AddRangeAsync(watchlists);
            }

            await context.SaveChangesAsync();
        }

        private static async Task SeedTestUsersAsync(UserManager<ApplicationUser> userManager)
        {
            if (await userManager.FindByEmailAsync("admin@test.com") == null)
            {
                var admin = new ApplicationUser { UserName = "admin@test.com", Email = "admin@test.com", EmailConfirmed = true };
                await userManager.CreateAsync(admin, "Admin123!");
                await userManager.AddToRoleAsync(admin, "Admin");
            }

            if (await userManager.FindByEmailAsync("user1@test.com") == null)
            {
                var user1 = new ApplicationUser { UserName = "user1@test.com", Email = "user1@test.com", EmailConfirmed = true };
                await userManager.CreateAsync(user1, "User123!");
                await userManager.AddToRoleAsync(user1, "User");
            }

            if (await userManager.FindByEmailAsync("user2@test.com") == null)
            {
                var user2 = new ApplicationUser { UserName = "user2@test.com", Email = "user2@test.com", EmailConfirmed = true };
                await userManager.CreateAsync(user2, "User123!");
                await userManager.AddToRoleAsync(user2, "User");
            }
        }

        private static async Task SeedTestActorsAsync(ApplicationDbContext context)
        {
            if (!await context.Actors.AnyAsync(a => a.FirstName == "Test" && a.LastName == "Actor1"))
            {
                context.Actors.Add(new Actor { FirstName = "Test", LastName = "Actor1", DateOfBirth = new DateTime(1980, 1, 1) });
            }
            if (!await context.Actors.AnyAsync(a => a.FirstName == "Test" && a.LastName == "Actor2"))
            {
                context.Actors.Add(new Actor { FirstName = "Test", LastName = "Actor2", DateOfBirth = new DateTime(1985, 5, 15) });
            }
            if (!await context.Actors.AnyAsync(a => a.FirstName == "Test" && a.LastName == "Actor3"))
            {
                context.Actors.Add(new Actor { FirstName = "Test", LastName = "Actor3", DateOfBirth = new DateTime(1990, 10, 20) });
            }
            await context.SaveChangesAsync();
        }

        private static async Task SeedTestSeriesAsync(ApplicationDbContext context)
        {
            if (!await context.Series.AnyAsync(s => s.Title == "Test Series 1"))
            {
                var dramaGenre = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Drama");
                if (dramaGenre != null)
                {
                    var series1 = new Series { Title = "Test Series 1", Description = "Test description 1", ReleaseDate = new DateTime(2020, 1, 1), Genre = "Drama", Rating = 8.5 };
                    context.Series.Add(series1);
                    await context.SaveChangesAsync();
                    context.SeriesGenres.Add(new SeriesGenre { SeriesId = series1.Id, GenreId = dramaGenre.Id });
                    await context.SaveChangesAsync();
                }
            }

            if (!await context.Series.AnyAsync(s => s.Title == "Test Series 2"))
            {
                var comedyGenre = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Comedy");
                if (comedyGenre != null)
                {
                    var series2 = new Series { Title = "Test Series 2", Description = "Test description 2", ReleaseDate = new DateTime(2021, 6, 1), Genre = "Comedy", Rating = 7.8 };
                    context.Series.Add(series2);
                    await context.SaveChangesAsync();
                    context.SeriesGenres.Add(new SeriesGenre { SeriesId = series2.Id, GenreId = comedyGenre.Id });
                    await context.SaveChangesAsync();
                }
            }

            if (!await context.Series.AnyAsync(s => s.Title == "Test Series 3"))
            {
                var actionGenre = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Action");
                if (actionGenre != null)
                {
                    var series3 = new Series { Title = "Test Series 3", Description = "Test description 3", ReleaseDate = new DateTime(2022, 3, 15), Genre = "Action", Rating = 9.0 };
                    context.Series.Add(series3);
                    await context.SaveChangesAsync();
                    context.SeriesGenres.Add(new SeriesGenre { SeriesId = series3.Id, GenreId = actionGenre.Id });
                    await context.SaveChangesAsync();
                }
            }
        }

        private static async Task SeedTestRatingsAsync(ApplicationDbContext context)
        {
            var adminUser = await context.Users.FirstOrDefaultAsync(u => u.Email == "admin@test.com");
            var user1 = await context.Users.FirstOrDefaultAsync(u => u.Email == "user1@test.com");
            var testSeries1 = await context.Series.FirstOrDefaultAsync(s => s.Title == "Test Series 1");
            var testSeries2 = await context.Series.FirstOrDefaultAsync(s => s.Title == "Test Series 2");
            var testSeries3 = await context.Series.FirstOrDefaultAsync(s => s.Title == "Test Series 3");

            if (adminUser != null && testSeries1 != null && !await context.Ratings.AnyAsync(r => r.UserId == adminUser.Id && r.SeriesId == testSeries1.Id))
            {
                context.Ratings.Add(new Rating { UserId = adminUser.Id, SeriesId = testSeries1.Id, Score = 9, CreatedAt = DateTime.UtcNow });
            }

            if (user1 != null && testSeries2 != null && !await context.Ratings.AnyAsync(r => r.UserId == user1.Id && r.SeriesId == testSeries2.Id))
            {
                context.Ratings.Add(new Rating { UserId = user1.Id, SeriesId = testSeries2.Id, Score = 8, CreatedAt = DateTime.UtcNow });
            }

            if (adminUser != null && testSeries3 != null && !await context.Ratings.AnyAsync(r => r.UserId == adminUser.Id && r.SeriesId == testSeries3.Id))
            {
                context.Ratings.Add(new Rating { UserId = adminUser.Id, SeriesId = testSeries3.Id, Score = 7, CreatedAt = DateTime.UtcNow });
            }

            await context.SaveChangesAsync();
        }

        private static async Task SeedTestWatchlistsAsync(ApplicationDbContext context)
        {
            var adminUser = await context.Users.FirstOrDefaultAsync(u => u.Email == "admin@test.com");
            var user1 = await context.Users.FirstOrDefaultAsync(u => u.Email == "user1@test.com");
            var testSeries1 = await context.Series.FirstOrDefaultAsync(s => s.Title == "Test Series 1");
            var testSeries2 = await context.Series.FirstOrDefaultAsync(s => s.Title == "Test Series 2");
            var testSeries3 = await context.Series.FirstOrDefaultAsync(s => s.Title == "Test Series 3");

            if (adminUser != null && testSeries1 != null && !await context.Watchlists.AnyAsync(w => w.UserId == adminUser.Id && w.SeriesId == testSeries1.Id))
            {
                context.Watchlists.Add(new Watchlist { UserId = adminUser.Id, SeriesId = testSeries1.Id, AddedAt = DateTime.UtcNow });
            }

            if (user1 != null && testSeries2 != null && !await context.Watchlists.AnyAsync(w => w.UserId == user1.Id && w.SeriesId == testSeries2.Id))
            {
                context.Watchlists.Add(new Watchlist { UserId = user1.Id, SeriesId = testSeries2.Id, AddedAt = DateTime.UtcNow });
            }

            if (adminUser != null && testSeries3 != null && !await context.Watchlists.AnyAsync(w => w.UserId == adminUser.Id && w.SeriesId == testSeries3.Id))
            {
                context.Watchlists.Add(new Watchlist { UserId = adminUser.Id, SeriesId = testSeries3.Id, AddedAt = DateTime.UtcNow });
            }

            await context.SaveChangesAsync();
        }

        /// <summary>
        /// Seeds 6 dummy users (1 admin + 5 normal users) with emails testuser1..testuser6@gmail.com
        /// Assigns roles: 1 Admin, 5 Users
        /// </summary>
        private static async Task SeedDummyUsersAsync(UserManager<ApplicationUser> userManager)
        {
            // Check if dummy users already exist
            if (await userManager.FindByEmailAsync("testuser1@gmail.com") != null)
            {
                return; // Already seeded
            }

            var users = new List<(string Email, string Role)>
            {
                ("testuser1@gmail.com", "Admin"),
                ("testuser2@gmail.com", "User"),
                ("testuser3@gmail.com", "User"),
                ("testuser4@gmail.com", "User"),
                ("testuser5@gmail.com", "User"),
                ("testuser6@gmail.com", "User")
            };

            foreach (var (email, role) in users)
            {
                if (await userManager.FindByEmailAsync(email) == null)
                {
                    var user = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        EmailConfirmed = true,
                        DateCreated = DateTime.UtcNow.AddDays(-Random.Next(1, 60))
                    };

                    var result = await userManager.CreateAsync(user, "Test123!");
                    if (result.Succeeded)
                    {
                        await userManager.AddToRoleAsync(user, role);
                    }
                }
            }
        }

        /// <summary>
        /// Seeds ratings and watchlist entries for several series
        /// Creates high ratings for some series to populate statistics
        /// </summary>
        private static async Task SeedRatingsAndWatchlistsAsync(ApplicationDbContext context)
        {
            // Get all users and series
            var users = await context.Users.ToListAsync();
            var series = await context.Series.Take(10).ToListAsync();

            if (users.Count == 0 || series.Count == 0)
            {
                return; // No users or series to seed
            }

            var ratings = new List<Rating>();
            var watchlists = new List<Watchlist>();

            // Create ratings with random scores (1-10) for all series
            foreach (var s in series)
            {
                // Each series gets ratings from multiple users
                var usersForSeries = users.Take(Random.Next(3, 6)).ToList();
                foreach (var user in usersForSeries)
                {
                    // Check if rating already exists
                    if (!await context.Ratings.AnyAsync(r => r.UserId == user.Id && r.SeriesId == s.Id))
                    {
                        // Random ratings (1-10)
                        var score = Random.Next(1, 11);
                        ratings.Add(new Rating
                        {
                            UserId = user.Id,
                            SeriesId = s.Id,
                            Score = score,
                            CreatedAt = DateTime.UtcNow.AddDays(-Random.Next(1, 90))
                        });
                    }
                }
            }

            // Create watchlist entries
            foreach (var user in users)
            {
                // Each user adds 3-5 series to watchlist
                var userSeries = series.OrderBy(x => Random.Next()).Take(Random.Next(3, 6));
                foreach (var s in userSeries)
                {
                    if (!await context.Watchlists.AnyAsync(w => w.UserId == user.Id && w.SeriesId == s.Id))
                    {
                        watchlists.Add(new Watchlist
                        {
                            UserId = user.Id,
                            SeriesId = s.Id,
                            AddedAt = DateTime.UtcNow.AddDays(-Random.Next(1, 90))
                        });
                    }
                }
            }

            if (ratings.Any())
            {
                await context.Ratings.AddRangeAsync(ratings);
            }

            if (watchlists.Any())
            {
                await context.Watchlists.AddRangeAsync(watchlists);
            }

            await context.SaveChangesAsync();
        }

        /// <summary>
        /// Seeds viewing events to populate monthly watching statistics and view counts
        /// Creates viewing events across the last 12 months for users and series
        /// </summary>
        private static async Task SeedViewingEventsAsync(ApplicationDbContext context)
        {
            // Check if viewing events already exist
            if (await context.ViewingEvents.AnyAsync())
            {
                return; // Already seeded
            }

            var users = await context.Users.ToListAsync();
            var series = await context.Series.Take(10).ToListAsync();

            if (users.Count == 0 || series.Count == 0)
            {
                return; // No users or series to seed
            }

            var viewingEvents = new List<ViewingEvent>();
            var now = DateTime.UtcNow;
            var twelveMonthsAgo = now.AddMonths(-12);

            // Generate viewing events across last 12 months
            foreach (var user in users.Take(8)) // Use up to 8 users
            {
                // Each user views 5-10 random series
                var userSeries = series.OrderBy(x => Random.Next()).Take(Random.Next(5, 11)).ToList();

                foreach (var s in userSeries)
                {
                    // Create 1-3 viewing events per user-series pair across different months
                    var eventCount = Random.Next(1, 4);
                    for (int i = 0; i < eventCount; i++)
                    {
                        // Random date within last 12 months
                        var daysAgo = Random.Next(0, 365);
                        var viewedAt = now.AddDays(-daysAgo);

                        viewingEvents.Add(new ViewingEvent
                        {
                            UserId = user.Id,
                            SeriesId = s.Id,
                            ViewedAt = viewedAt
                        });
                    }
                }
            }

            if (viewingEvents.Any())
            {
                await context.ViewingEvents.AddRangeAsync(viewingEvents);
                await context.SaveChangesAsync();
            }
        }

        /// <summary>
        /// Seeds example challenges
        /// </summary>
        private static async Task SeedChallengesAsync(ApplicationDbContext context)
        {
            // Check if challenges already exist
            if (await context.Challenges.AnyAsync())
            {
                return; // Already seeded
            }

            var challenges = new List<Challenge>
            {
                new Challenge
                {
                    Name = "Watch 10 Series",
                    Description = "Complete watching 10 different series. Track your progress and discover new shows!",
                    Difficulty = ChallengeDifficulty.Easy,
                    TargetCount = 10,
                    ParticipantsCount = 0,
                    CreatedAt = DateTime.UtcNow.AddDays(-30)
                },
                new Challenge
                {
                    Name = "Rate 50 Episodes",
                    Description = "Rate at least 50 episodes across different series. Share your opinions and help others discover great content!",
                    Difficulty = ChallengeDifficulty.Medium,
                    TargetCount = 50,
                    ParticipantsCount = 0,
                    CreatedAt = DateTime.UtcNow.AddDays(-25)
                },
                new Challenge
                {
                    Name = "Complete 5 Drama Series",
                    Description = "Finish watching 5 complete drama series from start to finish. Immerse yourself in compelling storylines!",
                    Difficulty = ChallengeDifficulty.Medium,
                    TargetCount = 5,
                    ParticipantsCount = 0,
                    CreatedAt = DateTime.UtcNow.AddDays(-20)
                },
                new Challenge
                {
                    Name = "Explore 3 New Genres",
                    Description = "Watch and rate series from 3 different genres you haven't explored before. Expand your viewing horizons!",
                    Difficulty = ChallengeDifficulty.Hard,
                    TargetCount = 3,
                    ParticipantsCount = 0,
                    CreatedAt = DateTime.UtcNow.AddDays(-15)
                },
                new Challenge
                {
                    Name = "100 Series Master",
                    Description = "The ultimate challenge! Watch and complete 100 different series. Are you up for the challenge?",
                    Difficulty = ChallengeDifficulty.Expert,
                    TargetCount = 100,
                    ParticipantsCount = 0,
                    CreatedAt = DateTime.UtcNow.AddDays(-10)
                }
            };

            await context.Challenges.AddRangeAsync(challenges);
            await context.SaveChangesAsync();
        }

        /// <summary>
        /// Seeds challenge progress entries for users
        /// </summary>
        private static async Task SeedChallengeProgressAsync(ApplicationDbContext context)
        {
            try
            {
                // Check if challenge progress already exists
                // Use try-catch in case table doesn't exist yet
                if (await context.ChallengeProgresses.AnyAsync())
                {
                    return; // Already seeded
                }
            }
            catch (Exception)
            {
                // Table might not exist yet, continue to create entries
                // The migration should create the table before this runs
            }

            var challenges = await context.Challenges.ToListAsync();
            var users = await context.Users.Take(8).ToListAsync();

            if (challenges.Count == 0 || users.Count == 0)
            {
                return; // No challenges or users to seed
            }

            var progressEntries = new List<ChallengeProgress>();

            // Assign random challenges to users with random progress
            foreach (var user in users)
            {
                // Each user participates in 1-3 random challenges
                var userChallenges = challenges.OrderBy(x => Random.Next()).Take(Random.Next(1, 4)).ToList();

                foreach (var challenge in userChallenges)
                {
                    // Check if progress entry already exists for this user-challenge pair
                    var exists = await context.ChallengeProgresses
                        .AnyAsync(cp => cp.UserId == user.Id && cp.ChallengeId == challenge.Id);
                    
                    if (exists)
                    {
                        continue; // Skip if already exists
                    }

                    var progressCount = Random.Next(0, challenge.TargetCount + 1);
                    var status = progressCount >= challenge.TargetCount
                        ? ChallengeProgressStatus.Completed
                        : ChallengeProgressStatus.InProgress;

                    progressEntries.Add(new ChallengeProgress
                    {
                        ChallengeId = challenge.Id,
                        UserId = user.Id,
                        ProgressCount = progressCount,
                        Status = status,
                        CompletedAt = status == ChallengeProgressStatus.Completed
                            ? DateTime.UtcNow.AddDays(-Random.Next(1, 30))
                            : null
                    });
                }
            }

            if (progressEntries.Any())
            {
                await context.ChallengeProgresses.AddRangeAsync(progressEntries);
                await context.SaveChangesAsync();

                // Update ParticipantsCount for each challenge
                foreach (var challenge in challenges)
                {
                    var participantCount = await context.ChallengeProgresses
                        .CountAsync(cp => cp.ChallengeId == challenge.Id);
                    challenge.ParticipantsCount = participantCount;
                }
                await context.SaveChangesAsync();
            }
        }
    }
}

