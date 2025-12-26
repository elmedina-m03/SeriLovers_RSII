using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Provides endpoints for managing custom watchlist collections.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Watchlist Collections")]
    public class WatchlistCollectionController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;

        public WatchlistCollectionController(
            ApplicationDbContext context,
            IMapper mapper,
            UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _mapper = mapper;
            _userManager = userManager;
        }

        private async Task<int?> GetCurrentUserIdAsync()
        {
            var user = await _userManager.GetUserAsync(User);
            return user?.Id;
        }

        /// <summary>
        /// Get all collections for the current user
        /// </summary>
        [HttpGet]
        [SwaggerOperation(Summary = "List collections", Description = "Retrieves all watchlist collections for the current user.")]
        public async Task<IActionResult> GetAll()
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var collections = await _context.WatchlistCollections
                .Include(c => c.Watchlists)
                .Where(c => c.UserId == currentUserId.Value)
                .OrderBy(c => c.Name)
                .ToListAsync();

            // Clean up duplicate Favorites folders - keep only the first one
            var favoritesCollections = collections
                .Where(c => c.Name.Equals("Favorites", StringComparison.OrdinalIgnoreCase) ||
                           c.Name.Equals("Favourite", StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (favoritesCollections.Count > 1)
            {
                // Keep the first one (oldest)
                var keepFavorites = favoritesCollections.OrderBy(c => c.CreatedAt).First();
                
                // Delete duplicates
                foreach (var duplicate in favoritesCollections.Where(c => c.Id != keepFavorites.Id))
                {
                    // Move series from duplicate to the kept Favorites folder
                    foreach (var watchlist in duplicate.Watchlists.ToList())
                    {
                        watchlist.CollectionId = keepFavorites.Id;
                    }
                    
                    _context.WatchlistCollections.Remove(duplicate);
                    collections.Remove(duplicate);
                }
                
                await _context.SaveChangesAsync();
            }

            var result = _mapper.Map<IEnumerable<WatchlistCollectionDto>>(collections);
            return Ok(result);
        }

        /// <summary>
        /// Get a specific collection with its series
        /// </summary>
        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Get collection", Description = "Retrieves a watchlist collection with all its series.")]
        public async Task<IActionResult> GetById(int id)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var collection = await _context.WatchlistCollections
                .Include(c => c.Watchlists)
                    .ThenInclude(w => w.Series)
                        .ThenInclude(s => s.SeriesGenres)
                            .ThenInclude(sg => sg.Genre)
                .Include(c => c.Watchlists)
                    .ThenInclude(w => w.Series)
                        .ThenInclude(s => s.SeriesActors)
                            .ThenInclude(sa => sa.Actor)
                .FirstOrDefaultAsync(c => c.Id == id && c.UserId == currentUserId.Value);

            if (collection == null)
            {
                return NotFound(new { message = $"Collection with ID {id} not found." });
            }

            var result = _mapper.Map<WatchlistCollectionDetailDto>(collection);
            return Ok(result);
        }

        /// <summary>
        /// Create a new collection
        /// </summary>
        [HttpPost]
        [SwaggerOperation(Summary = "Create collection", Description = "Creates a new watchlist collection for the current user.")]
        public async Task<IActionResult> Create([FromBody] WatchlistCollectionCreateDto dto)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            // Check if collection name already exists for this user
            var nameExists = await _context.WatchlistCollections
                .AnyAsync(c => c.UserId == currentUserId.Value && 
                              c.Name.ToLower() == dto.Name.Trim().ToLower());

            if (nameExists)
            {
                return BadRequest(new { message = $"A collection with the name '{dto.Name}' already exists." });
            }

            // Specifically prevent creating duplicate "Favorites" folders
            var nameLower = dto.Name.Trim().ToLower();
            if (nameLower == "favorites" || nameLower == "favourite")
            {
                var favoritesExists = await _context.WatchlistCollections
                    .AnyAsync(c => c.UserId == currentUserId.Value && 
                                  (c.Name.ToLower() == "favorites" || c.Name.ToLower() == "favourite"));

                if (favoritesExists)
                {
                    return BadRequest(new { message = "A Favorites folder already exists. You cannot create duplicate Favorites folders." });
                }
            }

            var collection = _mapper.Map<WatchlistCollection>(dto);
            collection.UserId = currentUserId.Value;
            collection.CreatedAt = DateTime.UtcNow;

            _context.WatchlistCollections.Add(collection);
            await _context.SaveChangesAsync();

            var result = _mapper.Map<WatchlistCollectionDto>(collection);
            return CreatedAtAction(nameof(GetById), new { id = collection.Id }, result);
        }

        /// <summary>
        /// Update a collection
        /// </summary>
        [HttpPut("{id}")]
        [SwaggerOperation(Summary = "Update collection", Description = "Updates an existing watchlist collection.")]
        public async Task<IActionResult> Update(int id, [FromBody] WatchlistCollectionUpdateDto dto)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var collection = await _context.WatchlistCollections
                .FirstOrDefaultAsync(c => c.Id == id && c.UserId == currentUserId.Value);

            if (collection == null)
            {
                return NotFound(new { message = $"Collection with ID {id} not found." });
            }

            // Prevent renaming the Favorites folder
            var isFavorites = collection.Name.Equals("Favorites", StringComparison.OrdinalIgnoreCase) ||
                             collection.Name.Equals("Favourite", StringComparison.OrdinalIgnoreCase);
            
            if (isFavorites && !string.IsNullOrWhiteSpace(dto.Name))
            {
                var newNameLower = dto.Name.Trim().ToLower();
                if (newNameLower != "favorites" && newNameLower != "favourite")
                {
                    return BadRequest(new { message = "The Favorites folder cannot be renamed." });
                }
            }

            // Check if new name conflicts with existing collection
            if (!string.IsNullOrWhiteSpace(dto.Name) && dto.Name.Trim().ToLower() != collection.Name.ToLower())
            {
                var nameExists = await _context.WatchlistCollections
                    .AnyAsync(c => c.UserId == currentUserId.Value && 
                                  c.Id != id &&
                                  c.Name.ToLower() == dto.Name.Trim().ToLower());

                if (nameExists)
                {
                    return BadRequest(new { message = $"A collection with the name '{dto.Name}' already exists." });
                }
            }

            _mapper.Map(dto, collection);
            await _context.SaveChangesAsync();

            var result = _mapper.Map<WatchlistCollectionDto>(collection);
            return Ok(result);
        }

        /// <summary>
        /// Delete a collection (series remain in default watchlist if CollectionId was set)
        /// </summary>
        [HttpDelete("{id}")]
        [SwaggerOperation(Summary = "Delete collection", Description = "Deletes a watchlist collection. Series are moved to default watchlist.")]
        public async Task<IActionResult> Delete(int id)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var collection = await _context.WatchlistCollections
                .Include(c => c.Watchlists)
                .FirstOrDefaultAsync(c => c.Id == id && c.UserId == currentUserId.Value);

            if (collection == null)
            {
                return NotFound(new { message = $"Collection with ID {id} not found." });
            }

            // Prevent deletion of the default Favorites folder
            var isFavorites = collection.Name.Equals("Favorites", StringComparison.OrdinalIgnoreCase) ||
                             collection.Name.Equals("Favourite", StringComparison.OrdinalIgnoreCase);
            
            if (isFavorites)
            {
                return BadRequest(new { message = "The default Favorites folder cannot be deleted." });
            }

            // Remove collection ID from watchlists (they'll become default watchlist items)
            foreach (var watchlist in collection.Watchlists)
            {
                watchlist.CollectionId = null;
            }

            _context.WatchlistCollections.Remove(collection);
            await _context.SaveChangesAsync();

            return Ok(new { message = "Collection deleted successfully." });
        }

        /// <summary>
        /// Add a series to a collection
        /// </summary>
        [HttpPost("{collectionId}/series/{seriesId}")]
        [SwaggerOperation(Summary = "Add series to collection", Description = "Adds a series to a specific collection.")]
        public async Task<IActionResult> AddSeries(int collectionId, int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var collection = await _context.WatchlistCollections
                .FirstOrDefaultAsync(c => c.Id == collectionId && c.UserId == currentUserId.Value);

            if (collection == null)
            {
                return NotFound(new { message = $"Collection with ID {collectionId} not found." });
            }

            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {seriesId} does not exist." });
            }

            // Check if already in this collection
            var existing = await _context.Watchlists
                .FirstOrDefaultAsync(w => w.UserId == currentUserId.Value && 
                                         w.SeriesId == seriesId && 
                                         w.CollectionId == collectionId);

            if (existing != null)
            {
                return Ok(new { message = "Series already in this collection." });
            }

            // Check if in default watchlist - update it, otherwise create new
            var defaultWatchlist = await _context.Watchlists
                .FirstOrDefaultAsync(w => w.UserId == currentUserId.Value && 
                                         w.SeriesId == seriesId && 
                                         w.CollectionId == null);

            if (defaultWatchlist != null)
            {
                defaultWatchlist.CollectionId = collectionId;
            }
            else
            {
                var watchlist = new Watchlist
                {
                    UserId = currentUserId.Value,
                    SeriesId = seriesId,
                    CollectionId = collectionId,
                    AddedAt = DateTime.UtcNow
                };
                _context.Watchlists.Add(watchlist);
            }

            await _context.SaveChangesAsync();
            return Ok(new { message = "Series added to collection." });
        }

        /// <summary>
        /// Remove a series from a collection (moves to default watchlist)
        /// </summary>
        [HttpDelete("{collectionId}/series/{seriesId}")]
        [SwaggerOperation(Summary = "Remove series from collection", Description = "Removes a series from a collection (moves to default watchlist).")]
        public async Task<IActionResult> RemoveSeries(int collectionId, int seriesId)
        {
            var currentUserId = await GetCurrentUserIdAsync();
            if (!currentUserId.HasValue)
            {
                return Unauthorized(new { message = "Unable to identify current user." });
            }

            var watchlist = await _context.Watchlists
                .FirstOrDefaultAsync(w => w.UserId == currentUserId.Value && 
                                         w.SeriesId == seriesId && 
                                         w.CollectionId == collectionId);

            // If series is not in this collection, it's already removed - return success (idempotent)
            if (watchlist == null)
            {
                return Ok(new { message = "Series already removed from collection." });
            }

            // Move to default watchlist (set CollectionId to null)
            watchlist.CollectionId = null;
            await _context.SaveChangesAsync();

            return Ok(new { message = "Series removed from collection." });
        }
    }
}

