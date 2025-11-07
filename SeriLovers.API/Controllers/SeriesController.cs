using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Interfaces;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System.Collections.Generic;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class SeriesController : ControllerBase
    {
        private readonly ISeriesService _seriesService;
        private readonly IMapper _mapper;

        public SeriesController(ISeriesService seriesService, IMapper mapper)
        {
            _seriesService = seriesService;
            _mapper = mapper;
        }

        [HttpGet]
        public IActionResult GetAll()
        {
            var series = _seriesService.GetAll();
            var result = _mapper.Map<IEnumerable<SeriesDto>>(series);
            return Ok(result);
        }

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var series = _seriesService.GetById(id);
            if (series == null)
                return NotFound();
            var result = _mapper.Map<SeriesDetailDto>(series);
            return Ok(result);
        }

        [HttpGet("search")]
        public IActionResult Search([FromQuery] string keyword)
        {
            var series = _seriesService.Search(keyword);
            var result = _mapper.Map<IEnumerable<SeriesDto>>(series);
            return Ok(result);
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
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
        public IActionResult Delete(int id)
        {
            _seriesService.Delete(id);
            return Ok();
        }
    }
}
