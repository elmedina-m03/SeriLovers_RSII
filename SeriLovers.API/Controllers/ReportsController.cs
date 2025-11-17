using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using SeriLovers.API.Data;
using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Swashbuckle.AspNetCore.Annotations;

namespace SeriLovers.API.Controllers
{
    /// <summary>
    /// Generates administrative CSV and PDF reports for the series catalogue.
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    [SwaggerTag("Reporting")]
    public class ReportsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public ReportsController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet("series-summary")]
        [SwaggerOperation(
            Summary = "Download series summary (CSV)",
            Description = "Exports all series with ratings, seasons, and episode counts to a CSV file.")]
        public async Task<IActionResult> GetSeriesSummaryCsv()
        {
            var reportData = await GetSeriesSummaryAsync();

            var builder = new StringBuilder();
            builder.AppendLine("Title,AverageRating,NumberOfSeasons,TotalEpisodes");

            foreach (var row in reportData)
            {
                var sanitizedTitle = row.Title.Replace("\"", "\"\"");
                builder.AppendLine($"\"{sanitizedTitle}\",{row.AverageRating:F2},{row.NumberOfSeasons},{row.TotalEpisodes}");
            }

            var bytes = Encoding.UTF8.GetBytes(builder.ToString());
            var fileName = $"series-summary-{DateTime.UtcNow:yyyyMMddHHmmss}.csv";
            return File(bytes, "text/csv", fileName);
        }

        [HttpGet("series-summary/pdf")]
        [SwaggerOperation(
            Summary = "Download series summary (PDF)",
            Description = "Exports all series with ratings, seasons, and episode counts to a PDF document.")]
        public async Task<IActionResult> GetSeriesSummaryPdf()
        {
            var reportData = await GetSeriesSummaryAsync();

            var document = Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Size(PageSizes.A4);
                    page.Margin(36);
                    page.PageColor(Colors.White);
                    page.DefaultTextStyle(x => x.FontSize(12));

                    page.Header().Element(header =>
                    {
                        header.AlignCenter().Text($"Series Summary Report - {DateTime.UtcNow:yyyy-MM-dd}")
                            .SemiBold()
                            .FontSize(20);
                    });

                    page.Content().PaddingVertical(10).Table(table =>
                    {
                        table.ColumnsDefinition(columns =>
                        {
                            columns.RelativeColumn(3);
                            columns.RelativeColumn();
                            columns.RelativeColumn();
                            columns.RelativeColumn();
                        });

                        table.Header(header =>
                        {
                            header.Cell().Element(CellStyle).Text("Title").SemiBold();
                            header.Cell().Element(CellStyle).Text("Avg Rating").SemiBold();
                            header.Cell().Element(CellStyle).Text("Seasons").SemiBold();
                            header.Cell().Element(CellStyle).Text("Episodes").SemiBold();
                        });

                        foreach (var row in reportData)
                        {
                            table.Cell().Element(CellStyle).Text(row.Title);
                            table.Cell().Element(CellStyle).Text(row.AverageRating.ToString("F2"));
                            table.Cell().Element(CellStyle).Text(row.NumberOfSeasons.ToString());
                            table.Cell().Element(CellStyle).Text(row.TotalEpisodes.ToString());
                        }

                        IContainer CellStyle(IContainer container)
                        {
                            return container.DefaultTextStyle(x => x.FontSize(11)).PaddingVertical(4).PaddingHorizontal(6);
                        }
                    });

                    page.Footer().Element(footer =>
                    {
                        footer.AlignCenter().Text(x =>
                        {
                            x.Span("Generated on ");
                            x.Span(DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss"));
                        });
                    });
                });
            });

            var pdfBytes = document.GeneratePdf();
            var fileName = $"series-summary-{DateTime.UtcNow:yyyyMMddHHmmss}.pdf";
            return File(pdfBytes, "application/pdf", fileName);
        }

        private async Task<SeriesSummaryRow[]> GetSeriesSummaryAsync()
        {
            return await _context.Series
                .AsNoTracking()
                .Select(series => new SeriesSummaryRow
                {
                    Title = series.Title,
                    AverageRating = series.Ratings.Any() ? series.Ratings.Average(r => r.Score) : 0,
                    NumberOfSeasons = series.Seasons.Count,
                    TotalEpisodes = series.Seasons.SelectMany(season => season.Episodes).Count()
                })
                .OrderByDescending(row => row.AverageRating)
                .ThenBy(row => row.Title)
                .ToArrayAsync();
        }

        private class SeriesSummaryRow
        {
            public string Title { get; set; } = string.Empty;
            public double AverageRating { get; set; }
            public int NumberOfSeasons { get; set; }
            public int TotalEpisodes { get; set; }
        }
    }
}
