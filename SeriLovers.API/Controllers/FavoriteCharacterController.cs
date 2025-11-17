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
    public class FavoriteCharacterController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IMapper _mapper;
        private readonly UserManager<ApplicationUser> _userManager;

        public FavoriteCharacterController(ApplicationDbContext context, IMapper mapper, UserManager<ApplicationUser> userManager)
        {
            _context = context;
            _mapper = mapper;
            _userManager = userManager;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<FavoriteCharacterDto>>> GetAll()
        {
            var entities = await _context.FavoriteCharacters
                .AsNoTracking()
                .Include(fc => fc.Actor)
                .Include(fc => fc.Series)
                .ToListAsync();

            return Ok(_mapper.Map<IEnumerable<FavoriteCharacterDto>>(entities));
        }

        [HttpGet("mine")]
        public async Task<ActionResult<IEnumerable<FavoriteCharacterDto>>> GetMine()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var entities = await _context.FavoriteCharacters
                .AsNoTracking()
                .Where(fc => fc.UserId == user.Id)
                .Include(fc => fc.Actor)
                .Include(fc => fc.Series)
                .ToListAsync();

            return Ok(_mapper.Map<IEnumerable<FavoriteCharacterDto>>(entities));
        }

        [HttpPost]
        public async Task<ActionResult<FavoriteCharacterDto>> Create([FromBody] FavoriteCharacterCreateDto dto)
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

            var exists = await _context.FavoriteCharacters.AnyAsync(fc =>
                fc.UserId == user.Id && fc.ActorId == dto.ActorId && fc.SeriesId == dto.SeriesId);

            if (exists)
            {
                return Conflict(new { message = "Favorite character already exists." });
            }

            var entity = _mapper.Map<FavoriteCharacter>(dto);
            entity.UserId = user.Id;

            _context.FavoriteCharacters.Add(entity);
            await _context.SaveChangesAsync();

            await _context.Entry(entity).Reference(fc => fc.Actor).LoadAsync();
            await _context.Entry(entity).Reference(fc => fc.Series).LoadAsync();

            var result = _mapper.Map<FavoriteCharacterDto>(entity);
            return CreatedAtAction(nameof(GetFavoriteCharacter), new { id = entity.Id }, result);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<FavoriteCharacterDto>> GetFavoriteCharacter(int id)
        {
            var entity = await _context.FavoriteCharacters
                .AsNoTracking()
                .Include(fc => fc.Actor)
                .Include(fc => fc.Series)
                .FirstOrDefaultAsync(fc => fc.Id == id);

            if (entity == null)
            {
                return NotFound();
            }

            return Ok(_mapper.Map<FavoriteCharacterDto>(entity));
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] FavoriteCharacterUpdateDto dto)
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

            var entity = await _context.FavoriteCharacters.FirstOrDefaultAsync(fc => fc.Id == id);
            if (entity == null)
            {
                return NotFound();
            }

            if (entity.UserId != user.Id)
            {
                return Forbid();
            }

            var duplicate = await _context.FavoriteCharacters.AnyAsync(fc =>
                fc.Id != id && fc.UserId == user.Id && fc.ActorId == dto.ActorId && fc.SeriesId == dto.SeriesId);
            if (duplicate)
            {
                return Conflict(new { message = "Favorite character already exists." });
            }

            entity.ActorId = dto.ActorId;
            entity.SeriesId = dto.SeriesId;

            await _context.SaveChangesAsync();
            await _context.Entry(entity).Reference(fc => fc.Actor).LoadAsync();
            await _context.Entry(entity).Reference(fc => fc.Series).LoadAsync();

            return Ok(_mapper.Map<FavoriteCharacterDto>(entity));
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
            {
                return Unauthorized();
            }

            var entity = await _context.FavoriteCharacters.FirstOrDefaultAsync(fc => fc.Id == id);
            if (entity == null)
            {
                return NotFound();
            }

            if (entity.UserId != user.Id)
            {
                return Forbid();
            }

            _context.FavoriteCharacters.Remove(entity);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}
