using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Interfaces;
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
    /// Manage TV series catalogue, including retrieval, updates, and admin operations.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Series Management")]
    public class SeriesController : ControllerBase
    {
        private readonly ISeriesService _seriesService;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IGenreService _genreService;

        public SeriesController(ISeriesService seriesService, IMapper mapper, UserManager<ApplicationUser> userManager, IGenreService genreService)
        {
            _seriesService = seriesService;
            _mapper = mapper;
            _userManager = userManager;
            _genreService = genreService;
        }

        [HttpGet]
        [SwaggerOperation(
            Summary = "List series",
            Description = "Retrieves a paginated list of series with optional filtering by genre ID or name, rating, and keyword.")]
        public async Task<IActionResult> GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] int? genreId = null,
            [FromQuery] string? genre = null,
            [FromQuery] double? minRating = null,
            [FromQuery] string? search = null,
            [FromQuery] int? year = null,
            [FromQuery] string? sortBy = null,
            [FromQuery] string? sortOrder = null)
        {
            // Convert genre name to ID if genre name is provided
            if (genreId == null && !string.IsNullOrEmpty(genre))
            {
                var genres = _genreService.GetAll();
                var foundGenre = genres.FirstOrDefault(g => g.Name.Equals(genre, StringComparison.OrdinalIgnoreCase));
                if (foundGenre != null)
                {
                    genreId = foundGenre.Id;
                }
            }

            var pagedSeries = await _seriesService.GetAllAsync(page, pageSize, genreId, minRating, search, year, sortBy, sortOrder);
            var items = _mapper.Map<IEnumerable<SeriesDto>>(pagedSeries.Items);

            var response = new PagedResponseDto<SeriesDto>
            {
                Items = items.ToList(),
                TotalItems = pagedSeries.TotalItems,
                TotalPages = pagedSeries.TotalPages,
                CurrentPage = pagedSeries.CurrentPage,
                PageSize = pagedSeries.PageSize
            };

            return Ok(response);
        }

        [HttpGet("{id}")]
        [SwaggerOperation(
            Summary = "Get series detail",
            Description = "Returns full details for a single series, including seasons, ratings, actors, and genres.")]
        public async Task<IActionResult> GetById(int id)
        {
            var series = await _seriesService.GetByIdAsync(id);
            if (series == null)
                return NotFound();
            var result = _mapper.Map<SeriesDetailDto>(series);
            return Ok(result);
        }

        [HttpGet("search")]
        [SwaggerOperation(
            Summary = "Search series",
            Description = "Performs a keyword search against series titles and descriptions.")]
        public async Task<IActionResult> Search([FromQuery] string keyword)
        {
            var series = await _seriesService.SearchAsync(keyword);
            var result = _mapper.Map<IEnumerable<SeriesDto>>(series);
            return Ok(result);
        }

        /// <remarks>
        /// Sample response:
        /// 
        /// ```
        /// [
        ///   {
        ///     "title": "Better Call Saul",
        ///     "genres": ["Crime Drama", "Drama"],
        ///     "averageRating": 9.1
        ///   }
        /// ]
        /// ```
        /// </remarks>
        /// <summary>
        /// Returns personalized series recommendations for the authenticated user.
        /// </summary>
        /// <remarks>
        /// Sample response:
        /// 
        /// ```
        /// [
        ///   {
        ///     "title": "Better Call Saul",
        ///     "genres": ["Crime Drama", "Drama"],
        ///     "averageRating": 9.1
        ///   }
        /// ]
        /// ```
        /// </remarks>
        [HttpGet("recommendations")]
        [SwaggerOperation(
            Summary = "Get recommended series",
            Description = "Returns personalized series recommendations for the authenticated user based on previous ratings.")]
        public async Task<IActionResult> GetRecommendations()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var recommendations = await _seriesService.GetRecommendationsAsync(user.Id);
            return Ok(recommendations);
        }

        /// <summary>
        /// Admin only. Adds a new series to the catalogue.
        /// </summary>
        /// <remarks>
        /// Sample request:
        /// 
        /// ```
        /// {
        ///   "title": "Dark",
        ///   "description": "A family saga with a supernatural twist.",
        ///   "releaseDate": "2017-12-01",
        ///   "rating": 9.0,
        ///   "genre": "Sci-Fi",
        ///   "genreIds": [1,4],
        ///   "actors": [
        ///     { "actorId": 2, "roleName": "Jonas Kahnwald" }
        ///   ]
        /// }
        /// ```
        /// 
        /// Sample response:
        /// 
        /// ```
        /// {
        ///   "id": 15,
        ///   "title": "Dark",
        ///   "description": "A family saga with a supernatural twist.",
        ///   "releaseDate": "2017-12-01T00:00:00",
        ///   "rating": 9.0,
        ///   "genres": [...],
        ///   "actors": [...],
        ///   "seasons": []
        /// }
        /// ```
        /// </remarks>
        [HttpPost]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Create a series",
            Description = "Admin only. Adds a new series to the catalogue.")]
        public async Task<IActionResult> Add([FromBody] SeriesUpsertDto seriesDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            // Convert genre names to IDs if Genres is provided
            if (seriesDto.Genres != null && seriesDto.Genres.Any() && !seriesDto.GenreIds.Any())
            {
                var genres = _genreService.GetAll();
                seriesDto.GenreIds = seriesDto.Genres
                    .Select(genreName => genres.FirstOrDefault(g => g.Name == genreName)?.Id ?? 0)
                    .Where(id => id > 0)
                    .ToList();
            }

            var series = _mapper.Map<Series>(seriesDto);
            _seriesService.Add(series);

            var created = await _seriesService.GetByIdAsync(series.Id);
            var result = _mapper.Map<SeriesDetailDto>(created);

            return CreatedAtAction(nameof(GetById), new { id = series.Id }, result);
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Update series",
            Description = "Admin only. Updates an existing series.")]
        public async Task<IActionResult> Update(int id, [FromBody] SeriesUpsertDto seriesDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var existing = await _seriesService.GetByIdAsync(id);
            if (existing == null)
            {
                return NotFound();
            }

            // Convert genre names to IDs if Genres is provided
            if (seriesDto.Genres != null && seriesDto.Genres.Any() && !seriesDto.GenreIds.Any())
            {
                var genres = _genreService.GetAll();
                seriesDto.GenreIds = seriesDto.Genres
                    .Select(genreName => genres.FirstOrDefault(g => g.Name == genreName)?.Id ?? 0)
                    .Where(id => id > 0)
                    .ToList();
            }

            var series = _mapper.Map<Series>(seriesDto);
            series.Id = id;

            _seriesService.Update(series);

            var updated = await _seriesService.GetByIdAsync(id);
            var result = _mapper.Map<SeriesDetailDto>(updated);

            return Ok(result);
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Delete series",
            Description = "Admin only. Removes a series and its related seasons and episodes.")]
        public IActionResult Delete(int id)
        {
            _seriesService.Delete(id);
            return Ok();
        }
    }
}
