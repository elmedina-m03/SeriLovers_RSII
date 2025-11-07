using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;

namespace SeriLovers.API.Services
{
    public class GenreService : IGenreService
    {
        private readonly ApplicationDbContext _context;

        public GenreService(ApplicationDbContext context)
        {
            _context = context;
        }

        public List<Genre> GetAll()
        {
            return _context.Genres
                           .Include(g => g.SeriesGenres)
                               .ThenInclude(sg => sg.Series)
                           .OrderBy(g => g.Name)
                           .ToList();
        }

        public Genre? GetById(int id)
        {
            return _context.Genres
                           .Include(g => g.SeriesGenres)
                               .ThenInclude(sg => sg.Series)
                           .FirstOrDefault(g => g.Id == id);
        }

        public void Add(Genre genre)
        {
            if (genre == null)
                throw new ArgumentNullException(nameof(genre));

            // Trim and validate name
            if (string.IsNullOrWhiteSpace(genre.Name))
                throw new ArgumentException("Genre name cannot be empty.", nameof(genre));

            genre.Name = genre.Name.Trim();

            // Check for duplicate name (case-insensitive)
            var existing = _context.Genres
                                  .FirstOrDefault(g => g.Name.ToLower() == genre.Name.ToLower());

            if (existing != null)
                throw new InvalidOperationException($"Genre with name '{genre.Name}' already exists.");

            _context.Genres.Add(genre);
            _context.SaveChanges();
        }

        public void Update(Genre genre)
        {
            if (genre == null)
                throw new ArgumentNullException(nameof(genre));

            var existing = _context.Genres
                                  .Include(g => g.SeriesGenres)
                                  .FirstOrDefault(g => g.Id == genre.Id);

            if (existing == null)
                throw new KeyNotFoundException($"Genre with ID {genre.Id} not found.");

            // Trim and validate name
            if (string.IsNullOrWhiteSpace(genre.Name))
                throw new ArgumentException("Genre name cannot be empty.", nameof(genre));

            genre.Name = genre.Name.Trim();

            // Check for duplicate name (case-insensitive, excluding current genre)
            var duplicate = _context.Genres
                                   .FirstOrDefault(g => g.Name.ToLower() == genre.Name.ToLower() && g.Id != genre.Id);

            if (duplicate != null)
                throw new InvalidOperationException($"Genre with name '{genre.Name}' already exists.");

            existing.Name = genre.Name;
            // Note: Series relationships should be managed through Series entity
            // This service only updates genre name

            _context.SaveChanges();
        }

        public void Delete(int id)
        {
            var genre = _context.Genres
                               .Include(g => g.SeriesGenres)
                               .FirstOrDefault(g => g.Id == id);

            if (genre == null)
                throw new KeyNotFoundException($"Genre with ID {id} not found.");

            // Check if genre is associated with any series
            if (genre.SeriesGenres != null && genre.SeriesGenres.Any())
            {
                throw new InvalidOperationException($"Cannot delete genre with ID {id} because it is associated with one or more series.");
            }

            _context.Genres.Remove(genre);
            _context.SaveChanges();
        }
    }
}
