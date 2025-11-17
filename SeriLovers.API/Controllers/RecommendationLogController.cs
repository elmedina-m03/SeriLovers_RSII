using AutoMapper;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Data;
using SeriLovers.API.Models;
using SeriLovers.API.Models.DTOs;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class RecommendationLogController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;

        public RecommendationLogController(ApplicationDbContext context, IMapper mapper, UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _mapper = mapper;
            _userManager = userManager;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<RecommendationLogDto>>> GetAll()
        {
            var entities = await _context.RecommendationLogs
                .AsNoTracking()
                .Include(l => l.Series)
                .Include(l => l.User)
                .ToListAsync();

            return Ok(_mapper.Map<IEnumerable<RecommendationLogDto>>(entities));
        }

        [HttpGet("mine")]
        public async Task<ActionResult<IEnumerable<RecommendationLogDto>>> GetMine()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var entities = await _context.RecommendationLogs
                .AsNoTracking()
                .Where(l => l.UserId == user.Id)
                .Include(l => l.Series)
                .OrderByDescending(l => l.RecommendedAt)
                .ToListAsync();

            return Ok(_mapper.Map<IEnumerable<RecommendationLogDto>>(entities));
        }

        [HttpPost]
        public async Task<ActionResult<RecommendationLogDto>> Create([FromBody] RecommendationLogCreateDto dto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var entity = _mapper.Map<RecommendationLog>(dto);
            entity.UserId = user.Id;

            _context.RecommendationLogs.Add(entity);
            await _context.SaveChangesAsync();

            await _context.Entry(entity).Reference(x => x.Series).LoadAsync();
            await _context.Entry(entity).Reference(x => x.User).LoadAsync();

            var result = _mapper.Map<RecommendationLogDto>(entity);
            return CreatedAtAction(nameof(GetRecommendationLog), new { id = entity.Id }, result);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<RecommendationLogDto>> GetRecommendationLog(int id)
        {
            var entity = await _context.RecommendationLogs
                .AsNoTracking()
                .Include(l => l.Series)
                .Include(l => l.User)
                .FirstOrDefaultAsync(l => l.Id == id);

            if (entity == null)
            {
                return NotFound();
            }

            return Ok(_mapper.Map<RecommendationLogDto>(entity));
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] RecommendationLogUpdateDto dto)
        {
            if (!ModelState.IsValid)
            {
                return ValidationProblem(ModelState);
            }

            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var entity = await _context.RecommendationLogs.FirstOrDefaultAsync(l => l.Id == id);
            if (entity == null)
            {
                return NotFound();
            }

            if (entity.UserId != user.Id)
            {
                return Forbid();
            }

            entity.Watched = dto.Watched;
            await _context.SaveChangesAsync();

            await _context.Entry(entity).Reference(x => x.Series).LoadAsync();
            await _context.Entry(entity).Reference(x => x.User).LoadAsync();

            return Ok(_mapper.Map<RecommendationLogDto>(entity));
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var entity = await _context.RecommendationLogs.FirstOrDefaultAsync(l => l.Id == id);
            if (entity == null)
            {
                return NotFound();
            }

            if (entity.UserId != user.Id)
            {
                return Forbid();
            }

            _context.RecommendationLogs.Remove(entity);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}
