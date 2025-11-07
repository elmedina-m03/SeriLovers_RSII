using AutoMapper;
using System;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System.Collections.Generic;
using System.Linq;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class RatingController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;

        public RatingController(ApplicationDbContext context, IMapper mapper)
        {
            _context = context;
            _mapper = mapper;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            var ratings = await _context.Ratings
                .Include(r => r.Series)
                .Include(r => r.User)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<RatingDto>>(ratings);

            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetById(int id)
        {
            var rating = await _context.Ratings
                .Include(r => r.Series)
                .Include(r => r.User)
                .FirstOrDefaultAsync(r => r.Id == id);

            if (rating == null)
            {
                return NotFound(new { message = $"Rating with ID {id} not found." });
            }

            var result = _mapper.Map<RatingDto>(rating);

            return Ok(result);
        }

        [HttpGet("series/{seriesId}")]
        public async Task<IActionResult> GetBySeries(int seriesId)
        {
            var seriesExists = await _context.Series.AnyAsync(s => s.Id == seriesId);
            if (!seriesExists)
            {
                return NotFound(new { message = $"Series with ID {seriesId} not found." });
            }

            var ratings = await _context.Ratings
                .Include(r => r.User)
                .Where(r => r.SeriesId == seriesId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<RatingDto>>(ratings);

            return Ok(result);
        }

        [HttpGet("user/{userId}")]
        public async Task<IActionResult> GetByUser(int userId)
        {
            var userExists = await _context.Users.AnyAsync(u => u.Id == userId);
            if (!userExists)
            {
                return NotFound(new { message = $"User with ID {userId} not found." });
            }

            var ratings = await _context.Ratings
                .Include(r => r.Series)
                .Where(r => r.UserId == userId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            var result = _mapper.Map<IEnumerable<RatingDto>>(ratings);

            return Ok(result);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] RatingCreateDto ratingDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var userExists = await _context.Users.AnyAsync(u => u.Id == ratingDto.UserId);
            if (!userExists)
            {
                return BadRequest(new { message = $"User with ID {ratingDto.UserId} does not exist." });
            }

            var seriesExists = await _context.Series.AnyAsync(s => s.Id == ratingDto.SeriesId);
            if (!seriesExists)
            {
                return BadRequest(new { message = $"Series with ID {ratingDto.SeriesId} does not exist." });
            }

            var existingRating = await _context.Ratings
                .FirstOrDefaultAsync(r => r.UserId == ratingDto.UserId && r.SeriesId == ratingDto.SeriesId);
            if (existingRating != null)
            {
                return Conflict(new { message = "User has already rated this series." });
            }

            var rating = _mapper.Map<Rating>(ratingDto);
            rating.CreatedAt = DateTime.UtcNow;

            _context.Ratings.Add(rating);
            await _context.SaveChangesAsync();

            await _context.Entry(rating).Reference(r => r.Series).LoadAsync();
            await _context.Entry(rating).Reference(r => r.User).LoadAsync();

            var result = _mapper.Map<RatingDto>(rating);

            return CreatedAtAction(nameof(GetById), new { id = rating.Id }, result);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] RatingUpdateDto ratingDto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var existingRating = await _context.Ratings.FindAsync(id);
            if (existingRating == null)
            {
                return NotFound(new { message = $"Rating with ID {id} not found." });
            }

            existingRating.Score = ratingDto.Score;
            existingRating.Comment = ratingDto.Comment;

            await _context.SaveChangesAsync();

            await _context.Entry(existingRating).Reference(r => r.Series).LoadAsync();
            await _context.Entry(existingRating).Reference(r => r.User).LoadAsync();

            var result = _mapper.Map<RatingDto>(existingRating);

            return Ok(result);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var rating = await _context.Ratings.FindAsync(id);
            if (rating == null)
            {
                return NotFound(new { message = $"Rating with ID {id} not found." });
            }

            _context.Ratings.Remove(rating);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}

