using System.Collections.Generic;

namespace SeriLovers.API.Models
{
    public class PagedResult<T>
    {
        public IReadOnlyList<T> Items { get; init; } = new List<T>();
        public int TotalItems { get; init; }
        public int TotalPages { get; init; }
        public int CurrentPage { get; init; }
        public int PageSize { get; init; }
    }
}

