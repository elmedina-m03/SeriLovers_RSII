using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System;
using System.Linq;

namespace SeriLovers.API.Services
{
    public class GenreService : IGenreService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<GenreService> _logger;

        public GenreService(ApplicationDbContext context, ILogger<GenreService> logger)
        {
            _context = context;
            _logger = logger;
        }

        public List<Genre> GetAll()
        {
            _logger.LogDebug("Retrieving all genres.");
            return _context.Genres
                           .Include(g => g.SeriesGenres)
                               .ThenInclude(sg => sg.Series)
                           .OrderBy(g => g.Name)
                           .ToList();
        }

        public Genre? GetById(int id)
        {
            _logger.LogDebug("Retrieving genre {GenreId}", id);
            return _context.Genres
                           .Include(g => g.SeriesGenres)
                               .ThenInclude(sg => sg.Series)
                           .FirstOrDefault(g => g.Id == id);
        }

        public void Add(Genre genre)
        {
            if (genre == null)
                throw new ArgumentNullException(nameof(genre));

            _logger.LogInformation("Creating genre {GenreName}", genre.Name);

            if (string.IsNullOrWhiteSpace(genre.Name))
                throw new ArgumentException("Genre name cannot be empty.", nameof(genre));

            genre.Name = genre.Name.Trim();

            var existing = _context.Genres
                                  .FirstOrDefault(g => g.Name.ToLower() == genre.Name.ToLower());

            if (existing != null)
            {
                _logger.LogWarning("Attempt to create duplicate genre {GenreName}", genre.Name);
                throw new InvalidOperationException($"Genre with name '{genre.Name}' already exists.");
            }

            _context.Genres.Add(genre);
            _context.SaveChanges();
            _logger.LogInformation("Genre {GenreName} created with id {GenreId}.", genre.Name, genre.Id);
        }

        public void Update(Genre genre)
        {
            if (genre == null)
                throw new ArgumentNullException(nameof(genre));

            _logger.LogInformation("Updating genre {GenreId}", genre.Id);

            var existing = _context.Genres
                                  .Include(g => g.SeriesGenres)
                                  .FirstOrDefault(g => g.Id == genre.Id);

            if (existing == null)
            {
                _logger.LogWarning("Genre {GenreId} not found for update.", genre.Id);
                throw new KeyNotFoundException($"Genre with ID {genre.Id} not found.");
            }

            if (string.IsNullOrWhiteSpace(genre.Name))
                throw new ArgumentException("Genre name cannot be empty.", nameof(genre));

            genre.Name = genre.Name.Trim();

            var duplicate = _context.Genres
                                   .FirstOrDefault(g => g.Name.ToLower() == genre.Name.ToLower() && g.Id != genre.Id);

            if (duplicate != null)
            {
                _logger.LogWarning("Attempt to rename genre {GenreId} to duplicate name {GenreName}", genre.Id, genre.Name);
                throw new InvalidOperationException($"Genre with name '{genre.Name}' already exists.");
            }

            existing.Name = genre.Name;
            _context.SaveChanges();
            _logger.LogInformation("Genre {GenreId} updated successfully.", genre.Id);
        }

        public void Delete(int id)
        {
            _logger.LogInformation("Deleting genre {GenreId}", id);
            var genre = _context.Genres
                               .Include(g => g.SeriesGenres)
                               .FirstOrDefault(g => g.Id == id);

            if (genre == null)
            {
                _logger.LogWarning("Genre {GenreId} not found for deletion.", id);
                throw new KeyNotFoundException($"Genre with ID {id} not found.");
            }

            if (genre.SeriesGenres != null && genre.SeriesGenres.Any())
            {
                _logger.LogWarning("Genre {GenreId} cannot be deleted because of related series.", id);
                throw new InvalidOperationException($"Cannot delete genre with ID {id} because it is associated with one or more series.");
            }

            _context.Genres.Remove(genre);
            _context.SaveChanges();
            _logger.LogInformation("Genre {GenreId} deleted successfully.", id);
        }
    }
}
