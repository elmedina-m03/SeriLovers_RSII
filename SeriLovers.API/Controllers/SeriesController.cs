using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
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

        public SeriesController(ISeriesService seriesService, IMapper mapper, UserManager<ApplicationUser> userManager)
        {
            _seriesService = seriesService;
            _mapper = mapper;
            _userManager = userManager;
        }

        [HttpGet]
        [SwaggerOperation(
            Summary = "List series",
            Description = "Retrieves a paginated list of series with optional filtering by genre ID, rating, and keyword.")]
        public IActionResult GetAll(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10,
            [FromQuery] int? genreId = null,
            [FromQuery] double? minRating = null,
            [FromQuery] string? search = null)
        {
            var pagedSeries = _seriesService.GetAll(page, pageSize, genreId, minRating, search);
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
        public IActionResult GetById(int id)
        {
            var series = _seriesService.GetById(id);
            if (series == null)
                return NotFound();
            var result = _mapper.Map<SeriesDetailDto>(series);
            return Ok(result);
        }

        [HttpGet("search")]
        [SwaggerOperation(
            Summary = "Search series",
            Description = "Performs a keyword search against series titles and descriptions.")]
        public IActionResult Search([FromQuery] string keyword)
        {
            var series = _seriesService.Search(keyword);
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
        public IActionResult Add([FromBody] SeriesUpsertDto seriesDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var series = _mapper.Map<Series>(seriesDto);
            _seriesService.Add(series);

            var created = _seriesService.GetById(series.Id);
            var result = _mapper.Map<SeriesDetailDto>(created);

            return CreatedAtAction(nameof(GetById), new { id = series.Id }, result);
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Update series",
            Description = "Admin only. Updates an existing series.")]
        public IActionResult Update(int id, [FromBody] SeriesUpsertDto seriesDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var existing = _seriesService.GetById(id);
            if (existing == null)
            {
                return NotFound();
            }

            var series = _mapper.Map<Series>(seriesDto);
            series.Id = id;

            _seriesService.Update(series);

            var updated = _seriesService.GetById(id);
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
