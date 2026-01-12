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

        /// <summary>
        /// Seeds recommendation logs for development/testing (only in Development environment)
        /// </summary>
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

            await context.SaveChangesAsync();
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

        /// <summary>
        /// Seeds catalog data (genres, actors, series, challenges) - runs in all environments
        /// </summary>
        public static async Task SeedCatalogDataAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();

            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
            var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole<int>>>();

            // Seed roles and ensure first user is admin
            await SeedRolesAndUsersAsync(context, userManager, roleManager);

            // Seed catalog data (genres, actors, series)
            await SeedGenresAsync(context);
            await SeedActorsAsync(context);
            await SeedSeriesAsync(context);

            // Seed series images
            await SeedSeriesImagesAsync(context);

            // Seed actor images
            await SeedActorImagesAsync(context);

            // Seed favorite characters (based on catalog data)
            await SeedFavoriteCharactersAsync(context);

            // Seed challenge definitions (catalog data - challenge progress comes from real user activity)
            await SeedChallengesAsync(context);
        }

        /// <summary>
        /// Seeds development/test data (dummy users, fake activity) - runs only in Development
        /// </summary>
        public static async Task SeedDevelopmentDataAsync(IServiceProvider serviceProvider)
        {
            using var scope = serviceProvider.CreateScope();

            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

            // Seed test users for development
            await SeedTestUsersAsync(userManager);
            await SeedDummyUsersAsync(userManager);

            // Seed test entities for development
            await SeedTestActorsAsync(context);
            await SeedTestSeriesAsync(context);

            // Seed dummy users with activity for development statistics
            await SeedDummyUsersWithActivityAsync(context, userManager);

            // Seed recommendation logs (for testing recommendation system)
            await SeedRecommendationLogsAsync(context);
        }

        /// <summary>
        /// Legacy method for backward compatibility - calls catalog seeding
        /// </summary>
        [Obsolete("Use SeedCatalogDataAsync for production and SeedDevelopmentDataAsync for development")]
        public static async Task Seed(IServiceProvider serviceProvider)
        {
            await SeedCatalogDataAsync(serviceProvider);
        }

        /// <summary>
        /// Seeds 10 dummy users with watchlist entries (NO RATINGS/REVIEWS)
        /// Ratings and reviews should only be created via real user actions
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
                        user = await userManager.FindByEmailAsync(email);
                        if (user != null)
                        {
                            await userManager.AddToRoleAsync(user, "User");
                            users.Add(user);
                        }
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

            // Generate activity across last 12 months (watchlist only - NO RATINGS)
            var now = DateTime.UtcNow;
            var months = Enumerable.Range(0, 12)
                .Select(m => now.AddMonths(-m))
                .ToList();

            foreach (var user in createdUsers)
            {
                // Each user adds to watchlist 3-5 random series (NO RATINGS)
                var userSeries = series.OrderBy(x => Random.Next()).Take(Random.Next(3, 6)).ToList();

                foreach (var s in userSeries)
                {
                    // Random month from last 12 months
                    var activityMonth = months[Random.Next(months.Count)];
                    var activityDate = activityMonth.AddDays(Random.Next(0, 28)); // Random day in month

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

            // Bulk insert watchlists only (NO RATINGS)
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
                var result = await userManager.CreateAsync(admin, "Admin123!");
                if (result.Succeeded)
                {
                    admin = await userManager.FindByEmailAsync("admin@test.com");
                    if (admin != null)
                    {
                        await userManager.AddToRoleAsync(admin, "Admin");
                    }
                }
            }

            if (await userManager.FindByEmailAsync("user1@test.com") == null)
            {
                var user1 = new ApplicationUser { UserName = "user1@test.com", Email = "user1@test.com", EmailConfirmed = true };
                var result = await userManager.CreateAsync(user1, "User123!");
                if (result.Succeeded)
                {
                    user1 = await userManager.FindByEmailAsync("user1@test.com");
                    if (user1 != null)
                    {
                        await userManager.AddToRoleAsync(user1, "User");
                    }
                }
            }

            if (await userManager.FindByEmailAsync("user2@test.com") == null)
            {
                var user2 = new ApplicationUser { UserName = "user2@test.com", Email = "user2@test.com", EmailConfirmed = true };
                var result = await userManager.CreateAsync(user2, "User123!");
                if (result.Succeeded)
                {
                    user2 = await userManager.FindByEmailAsync("user2@test.com");
                    if (user2 != null)
                    {
                        await userManager.AddToRoleAsync(user2, "User");
                    }
                }
            }

            if (await userManager.FindByNameAsync("desktop") == null)
            {
                var desktop = new ApplicationUser { UserName = "desktop", Email = "desktop@test.com", EmailConfirmed = true };
                var result = await userManager.CreateAsync(desktop, "test");
                if (result.Succeeded)
                {
                    desktop = await userManager.FindByNameAsync("desktop");
                    if (desktop != null)
                    {
                        await userManager.AddToRoleAsync(desktop, "User");
                    }
                }
            }

            if (await userManager.FindByNameAsync("mobile") == null)
            {
                var mobile = new ApplicationUser { UserName = "mobile", Email = "mobile@test.com", EmailConfirmed = true };
                var result = await userManager.CreateAsync(mobile, "test");
                if (result.Succeeded)
                {
                    mobile = await userManager.FindByNameAsync("mobile");
                    if (mobile != null)
                    {
                        await userManager.AddToRoleAsync(mobile, "User");
                    }
                }
            }

            if (await userManager.FindByNameAsync("Admin") == null)
            {
                var adminUser = new ApplicationUser { UserName = "Admin", Email = "admin@serilovers.com", EmailConfirmed = true };
                var adminResult = await userManager.CreateAsync(adminUser, "test");
                if (adminResult.Succeeded)
                {
                    adminUser = await userManager.FindByNameAsync("Admin");
                    if (adminUser != null)
                    {
                        await userManager.AddToRoleAsync(adminUser, "Admin");
                    }
                }
            }

            if (await userManager.FindByNameAsync("User") == null)
            {
                var user = new ApplicationUser { UserName = "User", Email = "user@serilovers.com", EmailConfirmed = true };
                var result = await userManager.CreateAsync(user, "test");
                if (result.Succeeded)
                {
                    user = await userManager.FindByNameAsync("User");
                    if (user != null)
                    {
                        await userManager.AddToRoleAsync(user, "User");
                    }
                }
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

        /// <summary>
        /// [REMOVED] Ratings should only be created via real user actions.
        /// This method is kept for reference but no longer called.
        /// </summary>
        [Obsolete("Ratings should only be created via real user actions. This method is no longer used.")]
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

        /// <summary>
        /// [REMOVED] Watchlists should only be created via real user actions.
        /// This method is kept for reference but no longer called.
        /// </summary>
        [Obsolete("Watchlists should only be created via real user actions. This method is no longer used.")]
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
        /// [REMOVED] Episode reviews should only be created via real user actions.
        /// This method is kept for reference but no longer called.
        /// </summary>
        [Obsolete("Episode reviews should only be created via real user actions. This method is no longer used.")]
        private static async Task SeedEpisodeReviewsAsync(ApplicationDbContext context)
        {
            // Check if reviews already exist
            if (await context.EpisodeReviews.AnyAsync())
            {
                return; // Skip if reviews already exist
            }

            // Get some users
            var users = await context.Users.Take(3).ToListAsync();
            if (users.Count == 0)
            {
                return; // No users to create reviews for
            }

            // Get some episodes
            var episodes = await context.Episodes
                .Include(e => e.Season)
                    .ThenInclude(s => s.Series)
                .Take(10)
                .ToListAsync();

            if (episodes.Count == 0)
            {
                return; // No episodes to create reviews for
            }

            var reviewTexts = new[]
            {
                "Great episode! Really enjoyed it.",
                "Amazing storytelling and character development.",
                "One of the best episodes of the season.",
                "Very very very good!",
                "Loved every minute of it!",
                "Excellent writing and acting.",
                "This episode was a masterpiece.",
                "Can't wait for the next one!"
            };

            var reviews = new List<EpisodeReview>();

            foreach (var user in users)
            {
                foreach (var episode in episodes)
                {
                    // Skip if review already exists
                    if (await context.EpisodeReviews
                        .AnyAsync(er => er.UserId == user.Id && er.EpisodeId == episode.Id))
                    {
                        continue;
                    }

                    // Random rating between 3 and 5
                    var rating = Random.Next(3, 6);
                    
                    // Random review text
                    var reviewText = reviewTexts[Random.Next(reviewTexts.Length)];
                    
                    // Random date within last 60 days
                    var daysAgo = Random.Next(0, 60);
                    var createdAt = DateTime.UtcNow.AddDays(-daysAgo);
                    
                    // 30% chance of being anonymous
                    var isAnonymous = Random.Next(10) < 3;

                    reviews.Add(new EpisodeReview
                    {
                        UserId = user.Id,
                        EpisodeId = episode.Id,
                        Rating = rating,
                        ReviewText = reviewText,
                        CreatedAt = createdAt,
                        IsAnonymous = isAnonymous
                    });
                }
            }

            if (reviews.Count > 0)
            {
                await context.EpisodeReviews.AddRangeAsync(reviews);
                await context.SaveChangesAsync();
            }
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
        /// [REMOVED] Ratings should only be created via real user actions.
        /// This method is kept for reference but no longer called.
        /// </summary>
        [Obsolete("Ratings should only be created via real user actions. This method is no longer used.")]
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
        /// [REMOVED] Viewing events should only be created via real user actions.
        /// This method is kept for reference but no longer called.
        /// </summary>
        [Obsolete("Viewing events should only be created via real user actions. This method is no longer used.")]
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
        /// Seeds initial challenge definitions (catalog data).
        /// Challenge progress is calculated from real user activity, not seeded.
        /// </summary>
        public static async Task SeedChallengesAsync(ApplicationDbContext context)
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
        /// Seeds series images from existing files in wwwroot/uploads/series
        /// </summary>
        private static async Task SeedSeriesImagesAsync(ApplicationDbContext context)
        {
            // Get all series that don't have images yet
            var seriesWithoutImages = await context.Series
                .Where(s => string.IsNullOrEmpty(s.ImageUrl))
                .ToListAsync();

            if (seriesWithoutImages.Count == 0)
            {
                return; // All series already have images
            }

            // Available images from wwwroot/uploads/series
            var availableImages = new[]
            {
                "/uploads/series/ee6fcdda-6eb4-4d26-a52d-a7592b8c5064.jpg",
                "/uploads/series/52074e01-5488-4711-8cf3-6b8d31e8c7ba.jpg",
                "/uploads/series/193023cc-777e-4132-86d3-0ca3de03f85d.jpg",
                "/uploads/series/3378201e-59b5-4095-962a-eea712d6e6a2.jpg",
                "/uploads/series/97bb735a-7e10-461b-b39f-6dae5c41043c.jpg",
                "/uploads/series/bcf3597c-f41c-4983-85d8-f00e8d105f7d.jpg",
                "/uploads/series/564e8102-dddc-42d0-8ce9-993f060dd1a9.jpg",
                "/uploads/series/0d325a7d-ce7c-4965-91e2-f47024f34045.jpg",
                "/uploads/series/73c4a968-f749-4a72-b067-2880c58ccf59.jpg",
                "/uploads/series/89947d14-de36-4784-bfad-09f0a09294c3.jpg",
                "/uploads/series/4e2fb20f-e8fb-480f-aead-8d0b8b724ff1.jpg",
                "/uploads/series/64de1f0e-242f-478a-9cae-18000b82d435.jpg",
                "/uploads/series/c58abe13-f5fb-400c-b480-d70bceb68918.jpg",
                "/uploads/series/c7fb56ff-97e2-4b18-8379-d30df59109c7.jpg",
                "/uploads/series/cc2d9e7c-6c60-4b76-be0c-35b8cbdadba8.jpg",
                "/uploads/series/e8d3d448-0679-4dde-be8e-70c65e541306.jpg",
                "/uploads/series/a4c1c5d8-1ec9-4e0b-b5ec-ed3627dc59a2.jpg",
                "/uploads/series/84c130dd-c07b-4de0-a7ac-f96b97b9fc64.jpg",
                "/uploads/series/4549d292-e4f4-47ef-89ae-8371267759c4.jpg",
                "/uploads/series/4713505b-547f-431d-9fca-c13f70e41d08.jpg",
                "/uploads/series/23020610-2eb9-445c-9583-a9bed20d7ecd.jpg",
                "/uploads/series/0874b386-7ac6-4e6e-9fcd-9a884cde6cc6.jpg",
                "/uploads/series/41297b9a-c40b-42d8-b56f-edd6b9814102.jpg"
            };

            var random = new Random();
            foreach (var series in seriesWithoutImages)
            {
                // Assign a random image from available images
                var randomImage = availableImages[random.Next(availableImages.Length)];
                series.ImageUrl = randomImage;
            }

            await context.SaveChangesAsync();
        }

        /// <summary>
        /// Seeds actor images from existing files in wwwroot/uploads/actors
        /// </summary>
        private static async Task SeedActorImagesAsync(ApplicationDbContext context)
        {
            // Get all actors that don't have images yet
            var actorsWithoutImages = await context.Actors
                .Where(a => string.IsNullOrEmpty(a.ImageUrl))
                .ToListAsync();

            if (actorsWithoutImages.Count == 0)
            {
                return; // All actors already have images
            }

            // Available images from wwwroot/uploads/actors
            var availableImages = new[]
            {
                "/uploads/actors/037eb0a6-0a09-4d34-a011-967574692cfb.jpg",
                "/uploads/actors/03b81a61-591c-43cd-a522-7d2e52fa3ac0.jpg",
                "/uploads/actors/08ffe115-4839-4037-bd4c-0141dd9c6768.jpg",
                "/uploads/actors/0cad9b28-6acb-4442-a300-97509ed31159.jpg",
                "/uploads/actors/0e90ff3f-4b1e-467c-98b4-c61a49cd3531.jpg",
                "/uploads/actors/100216cb-519f-44af-8d33-28ee0071ccb0.jpg",
                "/uploads/actors/1891480c-99e8-470c-86cc-9e8085e76234.jpg",
                "/uploads/actors/29fda531-af37-4e1e-b7ca-2a52e74155d7.jpg",
                "/uploads/actors/39e92b2d-1f6e-41a2-bf2d-1928d369645e.jpg",
                "/uploads/actors/3b89acbf-681f-48b9-b517-e90bbe461be5.jpg",
                "/uploads/actors/3e1bdd72-bc7e-44fe-977a-14a19e7b9e44.jpg",
                "/uploads/actors/4023fc4a-ca9e-4398-bad1-ffcdae3fa46e.jpg",
                "/uploads/actors/54ec1775-0e11-4941-ba89-2a4d5075f09d.jpg",
                "/uploads/actors/5503b5d9-9518-400c-be3a-8f1e2a555e33.jpg",
                "/uploads/actors/5fe76032-636c-4b0f-93dd-6564f912c2c1.jpg",
                "/uploads/actors/60e32131-60ad-4c55-a5a9-a54e3ee1dd18.jpg",
                "/uploads/actors/61ecbc5e-a711-4658-a470-40a448a8fd6f.jpg",
                "/uploads/actors/62477fec-7746-4cbe-9714-4a797490e923.jpeg",
                "/uploads/actors/66e4c0ca-cb6a-4b7e-98e8-bfb981426368.jpg",
                "/uploads/actors/69758db6-5e7f-4b2d-9b8c-4a0d36bb9b1c.jpg",
                "/uploads/actors/6b591092-8261-4434-a57b-4d4cd7cba834.jpg",
                "/uploads/actors/6d9c4ee7-1de6-4378-afb8-0358539203d1.jpg",
                "/uploads/actors/73b54684-5c46-4497-9133-03d61ab28ac8.jpg",
                "/uploads/actors/74b8cba6-da11-4221-940c-83c9d2067437.jpg",
                "/uploads/actors/7e4232b7-a2fa-48b3-b554-cca7a123e783.jpg",
                "/uploads/actors/92679616-83e5-45be-abb7-f5f52925cbb3.jpg",
                "/uploads/actors/95f7c71a-d404-4f2e-afec-91b3aae7b77c.jpg",
                "/uploads/actors/97dd2581-6350-432e-b60f-c69400dd9e97.jpg",
                "/uploads/actors/9b96fc8b-c727-4114-9e9a-1b55dd2722a2.jpg",
                "/uploads/actors/a61c2180-03ee-4a66-b7da-80ccdc646c6d.jpg",
                "/uploads/actors/aabf2625-3936-43d4-a69c-8fb119325d2b.jpg",
                "/uploads/actors/aeeb45bc-6e91-4447-8c5b-3611c9d44e9f.jpg",
                "/uploads/actors/af1742c3-9d85-410d-9bce-103a66f35bfe.jpg",
                "/uploads/actors/af728eaf-c0f7-4dbc-8670-2587307e1ae2.jpg",
                "/uploads/actors/b4530d14-0ad5-4adb-b44f-adeaf564abfc.jpg",
                "/uploads/actors/bfd5150b-e082-4f55-aeda-029cabad3b2b.jpg",
                "/uploads/actors/cdebb0d4-a3ab-4803-82df-5f8f2ba2adf5.jpg",
                "/uploads/actors/da4fd053-64f1-467b-9579-60522dc9faa1.jpg",
                "/uploads/actors/ea898907-d496-48d1-9081-8e2072fcfeba.jpg",
                "/uploads/actors/eae1fc99-da85-4410-9b4c-c7d4ed389ccc.jpg",
                "/uploads/actors/eb929e6c-81a8-47ec-8f71-09e39edd154f.jpg",
                "/uploads/actors/ec3eb0c6-e82d-4fbc-b534-7266fdaa9b80.jpg",
                "/uploads/actors/f9a92e21-6483-4f42-b1d7-11b1f636cbd1.jpg",
                "/uploads/actors/fdd94ba1-d054-4023-9737-bf9fd5076e47.jpg"
            };

            var random = new Random();
            foreach (var actor in actorsWithoutImages)
            {
                // Assign a random image from available images
                var randomImage = availableImages[random.Next(availableImages.Length)];
                actor.ImageUrl = randomImage;
            }

            await context.SaveChangesAsync();
        }

        /// <summary>
        /// Seeds user activity: episode progress, ratings, and challenge progress for multiple users
        /// This ensures that when professor runs the app, there will be sample data showing completed series with reviews
        /// </summary>
        private static async Task SeedUserActivityAsync(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            // Get or ensure test users exist (using regular users, not admin for activity seeding)
            var usersToSeed = new List<ApplicationUser>();
            var userEmails = new[] { "user1@test.com", "user2@test.com" };
            
            // First, get or create users
            foreach (var email in userEmails)
            {
                var user = await userManager.FindByEmailAsync(email);
                if (user == null)
                {
                    // Create user if it doesn't exist
                    user = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        EmailConfirmed = true
                    };
                    var result = await userManager.CreateAsync(user, "User123!");
                    if (result.Succeeded)
                    {
                        user = await userManager.FindByEmailAsync(email);
                        if (user != null)
                        {
                            await userManager.AddToRoleAsync(user, "User");
                            usersToSeed.Add(user);
                        }
                    }
                }
                else
                {
                    usersToSeed.Add(user);
                }
            }

            // Also get or create dummy users for additional activity
            var dummyUserEmails = new[] { "dummyuser1@test.com", "dummyuser2@test.com", "dummyuser3@test.com", "dummyuser4@test.com" };
            foreach (var email in dummyUserEmails)
            {
                var user = await userManager.FindByEmailAsync(email);
                if (user == null)
                {
                    // Create dummy user if it doesn't exist
                    user = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        EmailConfirmed = true,
                        DateCreated = DateTime.UtcNow.AddDays(-Random.Next(1, 90))
                    };
                    var result = await userManager.CreateAsync(user, "Dummy123!");
                    if (result.Succeeded)
                    {
                        user = await userManager.FindByEmailAsync(email);
                        if (user != null)
                        {
                            await userManager.AddToRoleAsync(user, "User");
                            usersToSeed.Add(user);
                        }
                    }
                }
                else
                {
                    usersToSeed.Add(user);
                }
            }

            if (usersToSeed.Count == 0)
            {
                return; // No users to seed activity for
            }

            // Note: We don't check for existing activity here because we check individually
            // for each episode/rating within the loops to avoid duplicates

            // Get all series with episodes
            var allSeries = await context.Series
                .Include(s => s.Seasons!)
                    .ThenInclude(season => season.Episodes)
                .ToListAsync();

            if (allSeries.Count == 0)
            {
                return; // No series to watch
            }

            var episodeProgresses = new List<EpisodeProgress>();
            var ratings = new List<Rating>();
            var challengeProgresses = new List<ChallengeProgress>();

            var reviewComments = new[]
            {
                "Amazing series! Highly recommend it to everyone.",
                "One of the best shows I've ever watched. The character development is outstanding.",
                "Great storytelling and excellent acting. Can't wait for more seasons!",
                "Absolutely loved it! The plot twists kept me on the edge of my seat.",
                "Fantastic series with well-developed characters and engaging storyline.",
                "Brilliant writing and amazing performances. A must-watch!",
                "This series exceeded all my expectations. Highly addictive!",
                "Perfect blend of drama and suspense. One of my favorites!",
                "Incredible character arcs and plot development. Masterpiece!",
                "Couldn't stop watching! Every episode was better than the last."
            };

            var random = new Random();

            // Different scenarios for each user
            // User 1: Watches 3 series completely, leaves reviews, has some challenge progress
            // User 2: Watches 2 series completely, leaves 1 review, has partial challenge progress
            // Dummy users 1-4: Each watches 1-2 series, leaves 1-2 reviews, has at least 1 challenge progress

            var userScenarios = new List<(int UserIndex, int SeriesCount, int ReviewCount, string ChallengeProgress)>();
            
            // Regular test users
            userScenarios.Add((0, 3, 3, "medium")); // user1@test.com
            userScenarios.Add((1, 2, 1, "low"));     // user2@test.com
            
            // Dummy users (indices 2-5 in usersToSeed list)
            if (usersToSeed.Count > 2)
            {
                userScenarios.Add((2, 2, 2, "medium")); // dummyuser1@test.com
            }
            if (usersToSeed.Count > 3)
            {
                userScenarios.Add((3, 1, 1, "low"));     // dummyuser2@test.com
            }
            if (usersToSeed.Count > 4)
            {
                userScenarios.Add((4, 2, 1, "low"));     // dummyuser3@test.com
            }
            if (usersToSeed.Count > 5)
            {
                userScenarios.Add((5, 1, 1, "low"));     // dummyuser4@test.com
            }

            foreach (var scenario in userScenarios)
            {
                if (scenario.UserIndex >= usersToSeed.Count)
                    continue;

                var user = usersToSeed[scenario.UserIndex];
                var (_, seriesCount, reviewCount, challengeProgress) = scenario;
                var seriesForUser = allSeries
                    .OrderBy(x => random.Next())
                    .Take(seriesCount)
                    .ToList();

                var userEpisodeProgresses = new List<EpisodeProgress>();
                var userRatings = new List<Rating>();
                var baseWatchedDate = DateTime.UtcNow.AddDays(-random.Next(1, 60));

                foreach (var series in seriesForUser)
                {
                    // Mark all episodes as watched
                    var allEpisodes = series.Seasons?
                        .SelectMany(s => s.Episodes ?? new List<Episode>())
                        .ToList() ?? new List<Episode>();

                    foreach (var episode in allEpisodes)
                    {
                        // Check if progress already exists
                        if (!await context.EpisodeProgresses
                            .AnyAsync(ep => ep.UserId == user.Id && ep.EpisodeId == episode.Id))
                        {
                            userEpisodeProgresses.Add(new EpisodeProgress
                            {
                                UserId = user.Id,
                                EpisodeId = episode.Id,
                                WatchedAt = baseWatchedDate.AddDays(-random.Next(0, 14)),
                                IsCompleted = true
                            });
                        }
                    }

                    // Add rating/review (only for some series based on scenario)
                    var shouldAddReview = userRatings.Count < reviewCount && allEpisodes.Count > 0;
                    if (shouldAddReview && !await context.Ratings
                        .AnyAsync(r => r.UserId == user.Id && r.SeriesId == series.Id))
                    {
                        userRatings.Add(new Rating
                        {
                            UserId = user.Id,
                            SeriesId = series.Id,
                            Score = random.Next(7, 11), // Score between 7-10
                            Comment = reviewComments[random.Next(reviewComments.Length)],
                            CreatedAt = baseWatchedDate
                        });
                    }
                }

                episodeProgresses.AddRange(userEpisodeProgresses);
                ratings.AddRange(userRatings);

                // Create challenge progress based on user activity
                var challenges = await context.Challenges.ToListAsync();
                var completedSeriesCount = seriesForUser.Count;
                var watchedEpisodesCount = userEpisodeProgresses.Count;

                foreach (var challenge in challenges)
                {
                    // Skip if progress already exists
                    if (await context.ChallengeProgresses
                        .AnyAsync(cp => cp.UserId == user.Id && cp.ChallengeId == challenge.Id))
                    {
                        continue;
                    }

                    int progressCount = 0;
                    bool shouldCreateProgress = false;

                    if (challenge.Name.Contains("Series"))
                    {
                        progressCount = completedSeriesCount;
                        shouldCreateProgress = challengeProgress != "low" || completedSeriesCount > 0;
                    }
                    else if (challenge.Name.Contains("Episodes"))
                    {
                        progressCount = watchedEpisodesCount;
                        shouldCreateProgress = watchedEpisodesCount > 0;
                    }
                    else if (challenge.Name.Contains("Drama"))
                    {
                        progressCount = seriesForUser.Count(s => s.Genre.Contains("Drama", StringComparison.OrdinalIgnoreCase));
                        shouldCreateProgress = progressCount > 0;
                    }
                    else if (challenge.Name.Contains("Master"))
                    {
                        // For 100 Series Master, give partial progress based on scenario
                        progressCount = scenario.ChallengeProgress == "high" ? random.Next(15, 25) : random.Next(5, 15);
                        shouldCreateProgress = true;
                    }

                    if (shouldCreateProgress && progressCount > 0)
                    {
                        var isCompleted = progressCount >= challenge.TargetCount;
                        challengeProgresses.Add(new ChallengeProgress
                        {
                            UserId = user.Id,
                            ChallengeId = challenge.Id,
                            ProgressCount = Math.Min(progressCount, challenge.TargetCount),
                            Status = isCompleted ? ChallengeProgressStatus.Completed : ChallengeProgressStatus.InProgress,
                            CompletedAt = isCompleted ? DateTime.UtcNow.AddDays(-random.Next(1, 10)) : null
                        });
                    }
                }
            }

            // Save all activity
            if (episodeProgresses.Any())
            {
                await context.EpisodeProgresses.AddRangeAsync(episodeProgresses);
            }

            if (ratings.Any())
            {
                await context.Ratings.AddRangeAsync(ratings);
            }

            if (challengeProgresses.Any())
            {
                await context.ChallengeProgresses.AddRangeAsync(challengeProgresses);
            }

            await context.SaveChangesAsync();
        }

    }
}

