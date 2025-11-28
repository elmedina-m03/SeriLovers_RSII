using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace SeriLovers.API.Services
{
    public interface IImageUploadService
    {
        Task<string?> UploadImageAsync(IFormFile file, string folderName);
        Task<bool> DeleteImageAsync(string imageUrl);
        string GetImageUrl(string fileName, string folderName);
    }

    public class ImageUploadService : IImageUploadService
    {
        private readonly IWebHostEnvironment _environment;
        private readonly string _baseUrl;

        public ImageUploadService(IWebHostEnvironment environment, IConfiguration configuration)
        {
            _environment = environment;
            _baseUrl = configuration["BaseUrl"] ?? "https://localhost:5001";
        }

        public async Task<string?> UploadImageAsync(IFormFile file, string folderName)
        {
            if (file == null || file.Length == 0)
                return null;

            // Validate file type
            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (!allowedExtensions.Contains(extension))
                throw new ArgumentException("Invalid file type. Only images (jpg, jpeg, png, gif, webp) are allowed.");

            // Validate file size (max 5MB)
            const long maxFileSize = 5 * 1024 * 1024; // 5MB
            if (file.Length > maxFileSize)
                throw new ArgumentException("File size exceeds the maximum allowed size of 5MB.");

            // Ensure wwwroot exists, use it explicitly for static file serving
            var webRootPath = _environment.WebRootPath;
            if (string.IsNullOrEmpty(webRootPath))
            {
                // If WebRootPath is null, create wwwroot in ContentRootPath
                webRootPath = Path.Combine(_environment.ContentRootPath, "wwwroot");
                if (!Directory.Exists(webRootPath))
                {
                    Directory.CreateDirectory(webRootPath);
                }
            }

            // Create uploads directory structure if it doesn't exist
            var uploadsPath = Path.Combine(webRootPath, "uploads", folderName);
            if (!Directory.Exists(uploadsPath))
            {
                Directory.CreateDirectory(uploadsPath);
            }

            // Generate unique filename
            var fileName = $"{Guid.NewGuid()}{extension}";
            var filePath = Path.Combine(uploadsPath, fileName);

            // Save file
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            // Return URL path (not full URL, will be served via static files)
            return $"/uploads/{folderName}/{fileName}";
        }

        public async Task<bool> DeleteImageAsync(string imageUrl)
        {
            if (string.IsNullOrEmpty(imageUrl))
                return false;

            try
            {
                // Ensure wwwroot exists
                var webRootPath = _environment.WebRootPath;
                if (string.IsNullOrEmpty(webRootPath))
                {
                    webRootPath = Path.Combine(_environment.ContentRootPath, "wwwroot");
                }

                // Remove leading slash if present
                var relativePath = imageUrl.TrimStart('/');
                var filePath = Path.Combine(webRootPath, relativePath);

                if (File.Exists(filePath))
                {
                    File.Delete(filePath);
                    return true;
                }
                return false;
            }
            catch
            {
                return false;
            }
        }

        public string GetImageUrl(string fileName, string folderName)
        {
            return $"/uploads/{folderName}/{fileName}";
        }
    }
}

