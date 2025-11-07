using SeriLovers.API.Data;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;

namespace SeriLovers.API.Services
{
    public class ActorService : IActorService
    {
        private readonly ApplicationDbContext _context;

        public ActorService(ApplicationDbContext context)
        {
            _context = context;
        }

        public List<Actor> GetAll()
        {
            return _context.Actors
                           .Include(a => a.SeriesActors)
                               .ThenInclude(sa => sa.Series)
                           .OrderBy(a => a.LastName)
                           .ThenBy(a => a.FirstName)
                           .ToList();
        }

        public Actor? GetById(int id)
        {
            return _context.Actors
                           .Include(a => a.SeriesActors)
                               .ThenInclude(sa => sa.Series)
                           .FirstOrDefault(a => a.Id == id);
        }

        public void Add(Actor actor)
        {
            if (actor == null)
                throw new ArgumentNullException(nameof(actor));

            _context.Actors.Add(actor);
            _context.SaveChanges();
        }

        public void Update(Actor actor)
        {
            if (actor == null)
                throw new ArgumentNullException(nameof(actor));

            var existing = _context.Actors
                                   .Include(a => a.SeriesActors)
                                   .FirstOrDefault(a => a.Id == actor.Id);

            if (existing == null)
                throw new KeyNotFoundException($"Actor with ID {actor.Id} not found.");

            // Update properties
            existing.FirstName = actor.FirstName;
            existing.LastName = actor.LastName;
            existing.DateOfBirth = actor.DateOfBirth;
            existing.Biography = actor.Biography;

            // Note: Series relationships should be managed through Series entity
            // This service only updates actor properties

            _context.SaveChanges();
        }

        public void Delete(int id)
        {
            var actor = _context.Actors
                               .Include(a => a.SeriesActors)
                               .FirstOrDefault(a => a.Id == id);

            if (actor == null)
                throw new KeyNotFoundException($"Actor with ID {id} not found.");

            // Check if actor is associated with any series
            if (actor.SeriesActors != null && actor.SeriesActors.Any())
            {
                throw new InvalidOperationException($"Cannot delete actor with ID {id} because they are associated with one or more series.");
            }

            _context.Actors.Remove(actor);
            _context.SaveChanges();
        }
    }
}
