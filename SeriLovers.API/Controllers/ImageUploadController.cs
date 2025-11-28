using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SeriLovers.API.Services;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ImageUploadController : ControllerBase
    {
        private readonly IImageUploadService _imageUploadService;

        public ImageUploadController(IImageUploadService imageUploadService)
        {
            _imageUploadService = imageUploadService;
        }

        /// <summary>
        /// Upload an image file
        /// </summary>
        /// <param name="file">The image file to upload</param>
        /// <param name="folder">Folder name (series, actors, avatars). Default: 'general'</param>
        /// <returns>The URL path to the uploaded image</returns>
        [HttpPost("upload")]
        [Authorize] // Require authentication
        public async Task<IActionResult> UploadImage(IFormFile file, [FromQuery] string folder = "general")
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest(new { message = "No file uploaded." });
            }

            try
            {
                // Validate folder name (security: prevent path traversal)
                var allowedFolders = new[] { "series", "actors", "avatars", "general" };
                if (!allowedFolders.Contains(folder.ToLowerInvariant()))
                {
                    return BadRequest(new { message = "Invalid folder name." });
                }

                var imageUrl = await _imageUploadService.UploadImageAsync(file, folder);
                
                if (string.IsNullOrEmpty(imageUrl))
                {
                    return BadRequest(new { message = "Failed to upload image." });
                }

                return Ok(new
                {
                    success = true,
                    imageUrl = imageUrl,
                    message = "Image uploaded successfully."
                });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An error occurred while uploading the image.", error = ex.Message });
            }
        }

        /// <summary>
        /// Delete an image file
        /// </summary>
        /// <param name="imageUrl">The URL path of the image to delete</param>
        [HttpDelete("delete")]
        [Authorize(Roles = "Admin")] // Only admins can delete
        public async Task<IActionResult> DeleteImage([FromQuery] string imageUrl)
        {
            if (string.IsNullOrEmpty(imageUrl))
            {
                return BadRequest(new { message = "Image URL is required." });
            }

            var deleted = await _imageUploadService.DeleteImageAsync(imageUrl);
            
            if (deleted)
            {
                return Ok(new { success = true, message = "Image deleted successfully." });
            }
            else
            {
                return NotFound(new { message = "Image not found or could not be deleted." });
            }
        }
    }
}

