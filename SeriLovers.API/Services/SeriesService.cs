using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using Microsoft.EntityFrameworkCore;
using System;

namespace SeriLovers.API.Services
{
    public class SeriesService : ISeriesService
    {
        private readonly ApplicationDbContext _context;

        public SeriesService(ApplicationDbContext context)
        {
            _context = context;
        }

        public List<Series> GetAll()
        {
            return _context.Series
                           .Include(s => s.Seasons)
                           .Include(s => s.Genres)
                           .Include(s => s.Actors)
                           .OrderBy(s => s.Title)
                           .ToList();
        }

        public Series? GetById(int id)
        {
            return _context.Series
                           .Include(s => s.Seasons)
                           .Include(s => s.Genres)
                           .Include(s => s.Actors)
                           .FirstOrDefault(s => s.Id == id);
        }

        public List<Series> Search(string keyword)
        {
            if (string.IsNullOrWhiteSpace(keyword))
                return GetAll();

            var lowerKeyword = keyword.ToLower();
            return _context.Series
                           .Include(s => s.Seasons)
                           .Include(s => s.Genres)
                           .Include(s => s.Actors)
                           .Where(s => s.Title.ToLower().Contains(lowerKeyword) ||
                                      s.Description.ToLower().Contains(lowerKeyword))
                           .OrderBy(s => s.Title)
                           .ToList();
        }

        public void Add(Series series)
        {
            if (series == null)
                throw new ArgumentNullException(nameof(series));

            if (string.IsNullOrWhiteSpace(series.Title))
                throw new ArgumentException("Series title cannot be empty.", nameof(series));

            _context.Series.Add(series);
            _context.SaveChanges();
        }

        public void Update(Series series)
        {
            if (series == null)
                throw new ArgumentNullException(nameof(series));

            var existing = _context.Series
                                  .Include(s => s.Genres)
                                  .Include(s => s.Actors)
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

            // Update many-to-many relationships
            // Clear existing relationships
            existing.Genres.Clear();
            existing.Actors.Clear();

            // Add new relationships if provided
            if (series.Genres != null && series.Genres.Any())
            {
                // Load genres from database to ensure they exist
                var genreIds = series.Genres.Select(g => g.Id).ToList();
                var genres = _context.Genres.Where(g => genreIds.Contains(g.Id)).ToList();
                foreach (var genre in genres)
                {
                    existing.Genres.Add(genre);
                }
            }

            if (series.Actors != null && series.Actors.Any())
            {
                // Load actors from database to ensure they exist
                var actorIds = series.Actors.Select(a => a.Id).ToList();
                var actors = _context.Actors.Where(a => actorIds.Contains(a.Id)).ToList();
                foreach (var actor in actors)
                {
                    existing.Actors.Add(actor);
                }
            }

            _context.SaveChanges();
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
    }
}
