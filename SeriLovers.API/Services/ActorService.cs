using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System;
using System.Linq;

namespace SeriLovers.API.Services
{
    public class ActorService : IActorService
    {
        private readonly ApplicationDbContext _context;
        private readonly ILogger<ActorService> _logger;

        public ActorService(ApplicationDbContext context, ILogger<ActorService> logger)
        {
            _context = context;
            _logger = logger;
        }

        public List<Actor> GetAll()
        {
            _logger.LogDebug("Retrieving all actors.");
            return _context.Actors
                           .AsSplitQuery()
                           .Include(a => a.SeriesActors)
                               .ThenInclude(sa => sa.Series)
                           .OrderBy(a => a.LastName)
                           .ThenBy(a => a.FirstName)
                           .ToList();
        }

        public Actor? GetById(int id)
        {
            _logger.LogDebug("Retrieving actor with id {ActorId}", id);
            return _context.Actors
                           .AsSplitQuery()
                           .Include(a => a.SeriesActors)
                               .ThenInclude(sa => sa.Series)
                           .FirstOrDefault(a => a.Id == id);
        }

        public void Add(Actor actor)
        {
            if (actor == null)
                throw new ArgumentNullException(nameof(actor));

            _logger.LogInformation("Creating actor {FirstName} {LastName}", actor.FirstName, actor.LastName);
            _context.Actors.Add(actor);
            _context.SaveChanges();
            _logger.LogInformation("Actor with id {ActorId} created successfully.", actor.Id);
        }

        public void Update(Actor actor)
        {
            if (actor == null)
                throw new ArgumentNullException(nameof(actor));

            _logger.LogInformation("Updating actor {ActorId}", actor.Id);
            var existing = _context.Actors
                                   .Include(a => a.SeriesActors)
                                   .FirstOrDefault(a => a.Id == actor.Id);

            if (existing == null)
            {
                _logger.LogWarning("Actor {ActorId} not found for update.", actor.Id);
                throw new KeyNotFoundException($"Actor with ID {actor.Id} not found.");
            }

            existing.FirstName = actor.FirstName;
            existing.LastName = actor.LastName;
            existing.DateOfBirth = actor.DateOfBirth;
            existing.Biography = actor.Biography;
            existing.ImageUrl = actor.ImageUrl;

            _context.SaveChanges();
            _logger.LogInformation("Actor {ActorId} updated successfully.", actor.Id);
        }

        public void Delete(int id)
        {
            _logger.LogInformation("Deleting actor {ActorId}", id);
            var actor = _context.Actors
                               .Include(a => a.SeriesActors)
                               .FirstOrDefault(a => a.Id == id);

            if (actor == null)
            {
                _logger.LogWarning("Actor {ActorId} not found for deletion.", id);
                throw new KeyNotFoundException($"Actor with ID {id} not found.");
            }

            if (actor.SeriesActors != null && actor.SeriesActors.Any())
            {
                _logger.LogWarning("Actor {ActorId} cannot be deleted because of existing series associations.", id);
                throw new InvalidOperationException($"Cannot delete actor with ID {id} because they are associated with one or more series.");
            }

            _context.Actors.Remove(actor);
            _context.SaveChanges();
            _logger.LogInformation("Actor {ActorId} deleted successfully.", id);
        }
    }
}
