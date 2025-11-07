using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;

namespace SeriLovers.API.Services
{
    public class SeriesService : ISeriesService
    {
        private readonly ApplicationDbContext _context;

        public SeriesService(ApplicationDbContext context)
        {
            _context = context;
        }

        private IQueryable<Series> QuerySeriesWithRelationships()
        {
            return _context.Series
                           .Include(s => s.Seasons)
                           .Include(s => s.SeriesGenres)
                               .ThenInclude(sg => sg.Genre)
                           .Include(s => s.SeriesActors)
                               .ThenInclude(sa => sa.Actor)
                           .Include(s => s.Ratings)
                               .ThenInclude(r => r.User)
                           .Include(s => s.Watchlists)
                               .ThenInclude(w => w.User);
        }

        public List<Series> GetAll()
        {
            var seriesList = QuerySeriesWithRelationships()
                .OrderBy(s => s.Title)
                .ToList();

            foreach (var series in seriesList)
            {
                HydrateSeries(series);
            }

            return seriesList;
        }

        public Series? GetById(int id)
        {
            var series = QuerySeriesWithRelationships()
                .FirstOrDefault(s => s.Id == id);

            if (series != null)
            {
                HydrateSeries(series);
            }

            return series;
        }

        public List<Series> Search(string keyword)
        {
            if (string.IsNullOrWhiteSpace(keyword))
            {
                return GetAll();
            }

            var lowerKeyword = keyword.ToLower();

            var results = QuerySeriesWithRelationships()
                .Where(s => s.Title.ToLower().Contains(lowerKeyword) ||
                            s.Description.ToLower().Contains(lowerKeyword))
                .OrderBy(s => s.Title)
                .ToList();

            foreach (var series in results)
            {
                HydrateSeries(series);
            }

            return results;
        }

        public void Add(Series series)
        {
            if (series == null)
                throw new ArgumentNullException(nameof(series));

            if (string.IsNullOrWhiteSpace(series.Title))
                throw new ArgumentException("Series title cannot be empty.", nameof(series));

            var incomingGenreIds = ExtractGenreIds(series);
            var incomingActorLinks = ExtractActorLinks(series);

            // Reset relational collections to avoid EF attempting to attach duplicate entities
            series.SeriesGenres = new List<SeriesGenre>();
            series.SeriesActors = new List<SeriesActor>();

            _context.Series.Add(series);
            _context.SaveChanges();

            if (incomingGenreIds.Count > 0)
            {
                foreach (var genreId in incomingGenreIds)
                {
                    _context.SeriesGenres.Add(new SeriesGenre
                    {
                        SeriesId = series.Id,
                        GenreId = genreId
                    });
                }
            }

            if (incomingActorLinks.Count > 0)
            {
                foreach (var link in incomingActorLinks)
                {
                    _context.SeriesActors.Add(new SeriesActor
                    {
                        SeriesId = series.Id,
                        ActorId = link.ActorId,
                        RoleName = link.RoleName
                    });
                }
            }

            if (incomingGenreIds.Count > 0 || incomingActorLinks.Count > 0)
            {
                _context.SaveChanges();
            }

            _context.Entry(series)
                .Collection(s => s.SeriesGenres)
                .Query()
                .Include(sg => sg.Genre)
                .Load();

            _context.Entry(series)
                .Collection(s => s.SeriesActors)
                .Query()
                .Include(sa => sa.Actor)
                .Load();

            HydrateSeries(series);
        }

        public void Update(Series series)
        {
            if (series == null)
                throw new ArgumentNullException(nameof(series));

            var existing = _context.Series
                                  .Include(s => s.SeriesGenres)
                                  .Include(s => s.SeriesActors)
                                  .FirstOrDefault(s => s.Id == series.Id);

            if (existing == null)
                throw new KeyNotFoundException($"Series with ID {series.Id} not found.");

            if (string.IsNullOrWhiteSpace(series.Title))
                throw new ArgumentException("Series title cannot be empty.", nameof(series));

            // Update basic properties
            existing.Title = series.Title;
            existing.Description = series.Description;
            existing.ReleaseDate = series.ReleaseDate;
            existing.Genre = series.Genre;
            existing.Rating = series.Rating;

            var incomingGenreIds = ExtractGenreIds(series);
            var incomingActorLinks = ExtractActorLinks(series);

            // Replace genre links
            existing.SeriesGenres.Clear();
            if (incomingGenreIds.Count > 0)
            {
                foreach (var genreId in incomingGenreIds)
                {
                    existing.SeriesGenres.Add(new SeriesGenre
                    {
                        SeriesId = existing.Id,
                        GenreId = genreId
                    });
                }
            }

            // Replace actor links
            existing.SeriesActors.Clear();
            if (incomingActorLinks.Count > 0)
            {
                foreach (var link in incomingActorLinks)
                {
                    existing.SeriesActors.Add(new SeriesActor
                    {
                        SeriesId = existing.Id,
                        ActorId = link.ActorId,
                        RoleName = link.RoleName
                    });
                }
            }

            _context.SaveChanges();

            _context.Entry(existing)
                .Collection(s => s.SeriesGenres)
                .Query()
                .Include(sg => sg.Genre)
                .Load();

            _context.Entry(existing)
                .Collection(s => s.SeriesActors)
                .Query()
                .Include(sa => sa.Actor)
                .Load();

            HydrateSeries(existing);

            // Reflect updates back to the incoming instance for controller responses
            series.SeriesGenres = existing.SeriesGenres.ToList();
            series.SeriesActors = existing.SeriesActors.ToList();
            series.Genres = existing.Genres.ToList();
            series.Actors = existing.Actors.ToList();
        }

        public void Delete(int id)
        {
            var series = _context.Series
                               .Include(s => s.Seasons)
                               .FirstOrDefault(s => s.Id == id);

            if (series == null)
                throw new KeyNotFoundException($"Series with ID {id} not found.");

            // Note: Seasons will be cascade deleted due to foreign key relationship
            _context.Series.Remove(series);
            _context.SaveChanges();
        }

        private List<int> ExtractGenreIds(Series series)
        {
            var genreIds = new HashSet<int>();

            if (series.SeriesGenres != null)
            {
                foreach (var link in series.SeriesGenres)
                {
                    var id = link.GenreId != 0 ? link.GenreId : link.Genre?.Id ?? 0;
                    if (id > 0)
                    {
                        genreIds.Add(id);
                    }
                }
            }

            if (series.Genres != null)
            {
                foreach (var genre in series.Genres)
                {
                    if (genre?.Id > 0)
                    {
                        genreIds.Add(genre.Id);
                    }
                }
            }

            return genreIds.ToList();
        }

        private List<(int ActorId, string? RoleName)> ExtractActorLinks(Series series)
        {
            var actorLinks = new Dictionary<int, string?>();

            if (series.SeriesActors != null)
            {
                foreach (var link in series.SeriesActors)
                {
                    var id = link.ActorId != 0 ? link.ActorId : link.Actor?.Id ?? 0;
                    if (id > 0 && !actorLinks.ContainsKey(id))
                    {
                        var roleName = string.IsNullOrWhiteSpace(link.RoleName) ? null : link.RoleName.Trim();
                        actorLinks[id] = roleName;
                    }
                }
            }

            if (series.Actors != null)
            {
                foreach (var actor in series.Actors)
                {
                    if (actor?.Id > 0 && !actorLinks.ContainsKey(actor.Id))
                    {
                        actorLinks[actor.Id] = null;
                    }
                }
            }

            return actorLinks
                .Select(kvp => (kvp.Key, kvp.Value))
                .Select(tuple => (ActorId: tuple.Key, RoleName: tuple.Value))
                .ToList();
        }

        private void HydrateSeries(Series series)
        {
            series.Genres = series.SeriesGenres?
                .Where(sg => sg.Genre != null)
                .Select(sg => sg.Genre!)
                .DistinctBy(g => g.Id)
                .ToList() ?? new List<Genre>();

            series.Actors = series.SeriesActors?
                .Where(sa => sa.Actor != null)
                .Select(sa => sa.Actor!)
                .DistinctBy(a => a.Id)
                .ToList() ?? new List<Actor>();

            if (series.Seasons != null)
            {
                var orderedSeasons = series.Seasons
                    .OrderBy(s => s.SeasonNumber)
                    .Select(s =>
                    {
                        if (s.Episodes != null)
                        {
                            s.Episodes = s.Episodes
                                .OrderBy(e => e.EpisodeNumber)
                                .ToList();
                        }
                        else
                        {
                            s.Episodes = new List<Episode>();
                        }

                        return s;
                    })
                    .ToList();

                series.Seasons = orderedSeasons;
            }
            else
            {
                series.Seasons = new List<Season>();
            }
        }
    }
}
