using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Models;
using System;
using System.Collections.Generic;

namespace SeriLovers.API.Data
{
    public class DbSeeder
    {
        public static async Task SeedRolesAndUsersAsync(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager,
            RoleManager<IdentityRole<int>> roleManager)
        {
            // Seed Roles
            await SeedRolesAsync(roleManager);

            // Assign Admin role to first user
            await AssignAdminToFirstUserAsync(context, userManager);
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
            // Check if database is empty (no series records)
            if (await context.Series.AnyAsync())
            {
                return; // Database already has data, skip seeding
            }

            // Get genres and actors for relationships
            var crimeDrama = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Crime Drama");
            var fantasyDrama = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Fantasy Drama");
            var comedy = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Comedy");
            var sciFiHorror = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Sci-Fi Horror");
            var historicalDrama = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Historical Drama");
            var drama = await context.Genres.FirstOrDefaultAsync(g => g.Name == "Drama");

            var bryanCranston = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Bryan" && a.LastName == "Cranston");
            var aaronPaul = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Aaron" && a.LastName == "Paul");
            var emiliaClarke = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Emilia" && a.LastName == "Clarke");
            var kitHarington = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Kit" && a.LastName == "Harington");
            var steveCarell = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Steve" && a.LastName == "Carell");
            var johnKrasinski = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "John" && a.LastName == "Krasinski");
            var millieBobbyBrown = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Millie Bobby" && a.LastName == "Brown");
            var davidHarbour = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "David" && a.LastName == "Harbour");
            var claireFoy = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Claire" && a.LastName == "Foy");
            var mattSmith = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Matt" && a.LastName == "Smith");
            var jenniferAniston = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Jennifer" && a.LastName == "Aniston");
            var matthewPerry = await context.Actors.FirstOrDefaultAsync(a => a.FirstName == "Matthew" && a.LastName == "Perry");

            var breakingBad = new Series
            {
                Title = "Breaking Bad",
                Description = "A high school chemistry teacher turned methamphetamine manufacturer partners with a former student to secure his family's future.",
                ReleaseDate = new DateTime(2008, 1, 20),
                Genre = "Crime Drama",
                Rating = 9.5
            };

            var gameOfThrones = new Series
            {
                Title = "Game of Thrones",
                Description = "Nine noble families fight for control over the lands of Westeros, while an ancient enemy returns after being dormant for millennia.",
                ReleaseDate = new DateTime(2011, 4, 17),
                Genre = "Fantasy Drama",
                Rating = 9.3
            };

            var theOffice = new Series
            {
                Title = "The Office",
                Description = "A mockumentary on a group of typical office workers, where the workday consists of ego clashes, inappropriate behavior, and tedium.",
                ReleaseDate = new DateTime(2005, 3, 24),
                Genre = "Comedy",
                Rating = 8.9
            };

            var strangerThings = new Series
            {
                Title = "Stranger Things",
                Description = "When a young boy vanishes, a small town uncovers a mystery involving secret experiments, terrifying supernatural forces and one strange little girl.",
                ReleaseDate = new DateTime(2016, 7, 15),
                Genre = "Sci-Fi Horror",
                Rating = 8.7
            };

            var theCrown = new Series
            {
                Title = "The Crown",
                Description = "Follows the political rivalries and romance of Queen Elizabeth II's reign and the events that shaped the second half of the 20th century.",
                ReleaseDate = new DateTime(2016, 11, 4),
                Genre = "Historical Drama",
                Rating = 8.6
            };

            var friends = new Series
            {
                Title = "Friends",
                Description = "Follows the personal and professional lives of six twenty to thirty-something-year-old friends living in Manhattan.",
                ReleaseDate = new DateTime(1994, 9, 22),
                Genre = "Comedy",
                Rating = 8.9
            };

            var initialSeries = new List<Series>
            {
                breakingBad,
                gameOfThrones,
                theOffice,
                strangerThings,
                theCrown,
                friends
            };

            await context.Series.AddRangeAsync(initialSeries);
            await context.SaveChangesAsync();

            var seriesActors = new List<SeriesActor>();
            var seriesGenres = new List<SeriesGenre>();
            var seasons = new List<Season>();

            void LinkGenre(Series series, Genre? genre)
            {
                if (genre != null)
                {
                    seriesGenres.Add(new SeriesGenre
                    {
                        SeriesId = series.Id,
                        GenreId = genre.Id
                    });
                }
            }

            void LinkActor(Series series, Actor? actor, string roleName)
            {
                if (actor != null)
                {
                    seriesActors.Add(new SeriesActor
                    {
                        SeriesId = series.Id,
                        ActorId = actor.Id,
                        RoleName = roleName
                    });
                }
            }

            // Breaking Bad
            LinkGenre(breakingBad, crimeDrama);
            LinkGenre(breakingBad, drama);
            LinkActor(breakingBad, bryanCranston, "Walter White");
            LinkActor(breakingBad, aaronPaul, "Jesse Pinkman");

            // Game of Thrones
            LinkGenre(gameOfThrones, fantasyDrama);
            LinkGenre(gameOfThrones, drama);
            LinkActor(gameOfThrones, emiliaClarke, "Daenerys Targaryen");
            LinkActor(gameOfThrones, kitHarington, "Jon Snow");

            // The Office
            LinkGenre(theOffice, comedy);
            LinkActor(theOffice, steveCarell, "Michael Scott");
            LinkActor(theOffice, johnKrasinski, "Jim Halpert");

            // Stranger Things
            LinkGenre(strangerThings, sciFiHorror);
            LinkGenre(strangerThings, drama);
            LinkActor(strangerThings, millieBobbyBrown, "Eleven");
            LinkActor(strangerThings, davidHarbour, "Jim Hopper");

            // The Crown
            LinkGenre(theCrown, historicalDrama);
            LinkGenre(theCrown, drama);
            LinkActor(theCrown, claireFoy, "Queen Elizabeth II");
            LinkActor(theCrown, mattSmith, "Prince Philip");

            // Friends
            LinkGenre(friends, comedy);
            LinkGenre(friends, drama);
            LinkActor(friends, jenniferAniston, "Rachel Green");
            LinkActor(friends, matthewPerry, "Chandler Bing");

            void AddSeasonsWithEpisodes(Series series, int numberOfSeasons = 2, int episodesPerSeason = 5)
            {
                for (int seasonNumber = 1; seasonNumber <= numberOfSeasons; seasonNumber++)
                {
                    var seasonRelease = series.ReleaseDate.AddYears(seasonNumber - 1);
                    var season = new Season
                    {
                        SeriesId = series.Id,
                        SeasonNumber = seasonNumber,
                        Title = $"{series.Title} - Season {seasonNumber}",
                        Description = $"Season {seasonNumber} of {series.Title}",
                        ReleaseDate = seasonRelease,
                        Episodes = new List<Episode>()
                    };

                    for (int episodeNumber = 1; episodeNumber <= episodesPerSeason; episodeNumber++)
                    {
                        var episode = new Episode
                        {
                            EpisodeNumber = episodeNumber,
                            Title = $"{series.Title} S{seasonNumber:D2}E{episodeNumber:D2}",
                            Description = $"Episode {episodeNumber} of season {seasonNumber} for {series.Title}.",
                            AirDate = seasonRelease.AddDays(7 * (episodeNumber - 1)),
                            DurationMinutes = 45,
                            Rating = null
                        };

                        season.Episodes.Add(episode);
                    }

                    seasons.Add(season);
                }
            }

            AddSeasonsWithEpisodes(breakingBad);
            AddSeasonsWithEpisodes(gameOfThrones);
            AddSeasonsWithEpisodes(theOffice);
            AddSeasonsWithEpisodes(strangerThings);
            AddSeasonsWithEpisodes(theCrown);
            AddSeasonsWithEpisodes(friends);

            if (seriesGenres.Count > 0)
            {
                await context.SeriesGenres.AddRangeAsync(seriesGenres);
            }

            if (seriesActors.Count > 0)
            {
                await context.SeriesActors.AddRangeAsync(seriesActors);
            }

            if (seriesGenres.Count > 0 || seriesActors.Count > 0)
            {
                await context.SaveChangesAsync();
            }

            if (seasons.Count > 0)
            {
                await context.Seasons.AddRangeAsync(seasons);
                await context.SaveChangesAsync();
            }
        }

        private static async Task SeedRolesAsync(RoleManager<IdentityRole<int>> roleManager)
        {
            string[] roles = { "Admin", "User" };

            foreach (var roleName in roles)
            {
                var roleExists = await roleManager.RoleExistsAsync(roleName);
                if (!roleExists)
                {
                    await roleManager.CreateAsync(new IdentityRole<int> { Name = roleName });
                }
            }
        }

        private static async Task AssignAdminToFirstUserAsync(
            ApplicationDbContext context,
            UserManager<ApplicationUser> userManager)
        {
            // Get all users
            var users = await userManager.Users.ToListAsync();

            if (users.Count > 0)
            {
                var firstUser = users[0];
                var isInAdminRole = await userManager.IsInRoleAsync(firstUser, "Admin");

                if (!isInAdminRole)
                {
                    await userManager.AddToRoleAsync(firstUser, "Admin");
                }
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
        }
    }
}

