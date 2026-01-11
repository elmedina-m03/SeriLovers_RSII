using Microsoft.EntityFrameworkCore;
using SeriLovers.Worker.Models;

namespace SeriLovers.Worker.Data
{
    public class WorkerDbContext : DbContext
    {
        public WorkerDbContext(DbContextOptions<WorkerDbContext> options)
            : base(options)
        {
        }

        public DbSet<RecommendationLog> RecommendationLogs { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<RecommendationLog>(entity =>
            {
                entity.ToTable("RecommendationLogs");
                entity.HasKey(e => e.Id);
                entity.Property(e => e.UserId).IsRequired();
                entity.Property(e => e.SeriesId).IsRequired();
                entity.Property(e => e.RecommendedAt).IsRequired();
                entity.Property(e => e.Watched).IsRequired().HasDefaultValue(false);

                entity.HasIndex(e => new { e.UserId, e.SeriesId });
            });
        }
    }
}

