using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class SeriesController : ControllerBase
    {
        private readonly ISeriesService _seriesService;

        public SeriesController(ISeriesService seriesService)
        {
            _seriesService = seriesService;
        }

        [HttpGet]
        public IActionResult GetAll() => Ok(_seriesService.GetAll());

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var series = _seriesService.GetById(id);
            if (series == null)
                return NotFound();
            return Ok(series);
        }

        [HttpGet("search")]
        public IActionResult Search([FromQuery] string keyword) =>
            Ok(_seriesService.Search(keyword));

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public IActionResult Add([FromBody] Series series)
        {
            _seriesService.Add(series);
            return Ok(series);
        }

        [HttpPut]
        [Authorize(Roles = "Admin")]
        public IActionResult Update([FromBody] Series series)
        {
            _seriesService.Update(series);
            return Ok(series);
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        public IActionResult Delete(int id)
        {
            _seriesService.Delete(id);
            return Ok();
        }
    }
}
