using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace SeriLovers.API.Models.DTOs
{
    public class PagedResponseDto<T>
    {
        [Required]
        public IList<T> Items { get; set; } = new List<T>();

        [Required]
        public int TotalItems { get; set; }

        [Required]
        public int TotalPages { get; set; }

        [Required]
        public int CurrentPage { get; set; }

        [Required]
        public int PageSize { get; set; }
    }
}

