using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SeriLovers.API.Models;

namespace SeriLovers.API.Data
{
    public class ApplicationDbContext : IdentityDbContext<ApplicationUser, IdentityRole<int>, int>
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<Series> Series { get; set; }
        public DbSet<Season> Seasons { get; set; }
        public DbSet<Episode> Episodes { get; set; }
        public DbSet<Actor> Actors { get; set; }
        public DbSet<Genre> Genres { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Configure Series entity
            modelBuilder.Entity<Series>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Description).HasMaxLength(2000);
                entity.Property(e => e.Rating).HasPrecision(3, 2);
                entity.Property(e => e.Genre).HasMaxLength(100);
            });

            // Configure Season entity
            modelBuilder.Entity<Season>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Description).HasMaxLength(2000);
                
                entity.HasOne(s => s.Series)
                    .WithMany(series => series.Seasons)
                    .HasForeignKey(s => s.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure Episode entity
            modelBuilder.Entity<Episode>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Description).HasMaxLength(2000);
                entity.Property(e => e.Rating).HasPrecision(3, 2);
                
                entity.HasOne(e => e.Season)
                    .WithMany(season => season.Episodes)
                    .HasForeignKey(e => e.SeasonId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure Actor entity
            modelBuilder.Entity<Actor>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.FirstName).IsRequired().HasMaxLength(100);
                entity.Property(e => e.LastName).IsRequired().HasMaxLength(100);
                entity.Property(e => e.Biography).HasMaxLength(2000);
            });

            // Configure Genre entity
            modelBuilder.Entity<Genre>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
                entity.HasIndex(e => e.Name).IsUnique();
            });

            // Configure many-to-many: Series <-> Genre
            modelBuilder.Entity<Series>()
                .HasMany(s => s.Genres)
                .WithMany(g => g.Series)
                .UsingEntity(j => j.ToTable("SeriesGenres"));

            // Configure many-to-many: Series <-> Actor
            modelBuilder.Entity<Series>()
                .HasMany(s => s.Actors)
                .WithMany(a => a.Series)
                .UsingEntity(j => j.ToTable("SeriesActors"));
        }
    }
}

