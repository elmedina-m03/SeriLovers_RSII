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
        public DbSet<SeriesActor> SeriesActors { get; set; }
        public DbSet<SeriesGenre> SeriesGenres { get; set; }
        public DbSet<Rating> Ratings { get; set; }
        public DbSet<Watchlist> Watchlists { get; set; }
        public DbSet<WatchlistCollection> WatchlistCollections { get; set; }
        public DbSet<FavoriteCharacter> FavoriteCharacters { get; set; }
        public DbSet<RecommendationLog> RecommendationLogs { get; set; }
        public DbSet<Challenge> Challenges { get; set; }
        public DbSet<ChallengeProgress> ChallengeProgresses { get; set; }
        public DbSet<ViewingEvent> ViewingEvents { get; set; }
        public DbSet<EpisodeProgress> EpisodeProgresses { get; set; }
        public DbSet<EpisodeReview> EpisodeReviews { get; set; }

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

            modelBuilder.Entity<FavoriteCharacter>(entity =>
            {
                entity.HasKey(fc => fc.Id);
                entity.HasIndex(fc => new { fc.UserId, fc.ActorId, fc.SeriesId }).IsUnique();

                entity.HasOne(fc => fc.User)
                    .WithMany(u => u.FavoriteCharacters)
                    .HasForeignKey(fc => fc.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(fc => fc.Actor)
                    .WithMany(a => a.FavoriteCharacters)
                    .HasForeignKey(fc => fc.ActorId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(fc => fc.Series)
                    .WithMany(s => s.FavoriteCharacters)
                    .HasForeignKey(fc => fc.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<RecommendationLog>(entity =>
            {
                entity.HasKey(rl => rl.Id);
                entity.HasIndex(rl => new { rl.UserId, rl.SeriesId, rl.RecommendedAt });

                entity.HasOne(rl => rl.User)
                    .WithMany(u => u.RecommendationLogs)
                    .HasForeignKey(rl => rl.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(rl => rl.Series)
                    .WithMany(s => s.RecommendationLogs)
                    .HasForeignKey(rl => rl.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
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

            // Configure many-to-many join entity: Series <-> Actor
            modelBuilder.Entity<SeriesActor>(entity =>
            {
                entity.HasKey(sa => new { sa.SeriesId, sa.ActorId });

                entity.Property(sa => sa.RoleName).HasMaxLength(150);

                entity.HasOne(sa => sa.Series)
                    .WithMany(s => s.SeriesActors)
                    .HasForeignKey(sa => sa.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(sa => sa.Actor)
                    .WithMany(a => a.SeriesActors)
                    .HasForeignKey(sa => sa.ActorId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure many-to-many join entity: Series <-> Genre
            modelBuilder.Entity<SeriesGenre>(entity =>
            {
                entity.HasKey(sg => new { sg.SeriesId, sg.GenreId });

                entity.HasOne(sg => sg.Series)
                    .WithMany(s => s.SeriesGenres)
                    .HasForeignKey(sg => sg.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(sg => sg.Genre)
                    .WithMany(g => g.SeriesGenres)
                    .HasForeignKey(sg => sg.GenreId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure Rating entity
            modelBuilder.Entity<Rating>(entity =>
            {
                entity.HasKey(r => r.Id);
                entity.Property(r => r.Score).IsRequired();
                entity.Property(r => r.Comment).HasMaxLength(2000);
                entity.Property(r => r.CreatedAt).HasDefaultValueSql("GETUTCDATE()");

                entity.HasIndex(r => new { r.UserId, r.SeriesId }).IsUnique();

                entity.HasOne(r => r.User)
                    .WithMany(u => u.Ratings)
                    .HasForeignKey(r => r.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(r => r.Series)
                    .WithMany(s => s.Ratings)
                    .HasForeignKey(r => r.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure WatchlistCollection entity
            // TODO: Uncomment after migration is applied to create WatchlistCollections table
            // modelBuilder.Entity<WatchlistCollection>(entity =>
            // {
            //     entity.HasKey(wc => wc.Id);
            //     entity.Property(wc => wc.Name).IsRequired().HasMaxLength(100);
            //     entity.Property(wc => wc.Description).HasMaxLength(500);
            //     entity.Property(wc => wc.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
            //
            //     entity.HasIndex(wc => new { wc.UserId, wc.Name }).IsUnique();
            //
            //     entity.HasOne(wc => wc.User)
            //         .WithMany()
            //         .HasForeignKey(wc => wc.UserId)
            //         .OnDelete(DeleteBehavior.Cascade);
            // });

            // Configure Watchlist entity
            modelBuilder.Entity<Watchlist>(entity =>
            {
                entity.HasKey(w => w.Id);
                entity.Property(w => w.AddedAt).HasDefaultValueSql("GETUTCDATE()");

                // Index to prevent duplicate entries (same user, series, and collection)
                entity.HasIndex(w => new { w.UserId, w.SeriesId, w.CollectionId }).IsUnique();

                entity.HasOne(w => w.User)
                    .WithMany(u => u.Watchlists)
                    .HasForeignKey(w => w.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(w => w.Series)
                    .WithMany(s => s.Watchlists)
                    .HasForeignKey(w => w.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
                
                // Configure relationship with WatchlistCollection
                entity.HasOne(w => w.Collection)
                    .WithMany(c => c.Watchlists)
                    .HasForeignKey(w => w.CollectionId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

            // Configure Challenge entity
            modelBuilder.Entity<Challenge>(entity =>
            {
                entity.HasKey(c => c.Id);
                entity.Property(c => c.Name).IsRequired().HasMaxLength(200);
                entity.Property(c => c.Description).HasMaxLength(2000);
                entity.Property(c => c.Difficulty).IsRequired();
                entity.Property(c => c.TargetCount).IsRequired();
                entity.Property(c => c.ParticipantsCount).HasDefaultValue(0);
                entity.Property(c => c.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
            });

            // Configure ChallengeProgress entity
            modelBuilder.Entity<ChallengeProgress>(entity =>
            {
                entity.HasKey(cp => cp.Id);
                entity.Property(cp => cp.ProgressCount).IsRequired().HasDefaultValue(0);
                entity.Property(cp => cp.Status).IsRequired().HasDefaultValue(ChallengeProgressStatus.InProgress);
                entity.HasIndex(cp => new { cp.ChallengeId, cp.UserId }).IsUnique();

                entity.HasOne(cp => cp.Challenge)
                    .WithMany()
                    .HasForeignKey(cp => cp.ChallengeId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(cp => cp.User)
                    .WithMany()
                    .HasForeignKey(cp => cp.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure ViewingEvent entity
            modelBuilder.Entity<ViewingEvent>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.ViewedAt).IsRequired();
                entity.HasIndex(e => new { e.UserId, e.SeriesId, e.ViewedAt });

                entity.HasOne(e => e.User)
                    .WithMany()
                    .HasForeignKey(e => e.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Series)
                    .WithMany()
                    .HasForeignKey(e => e.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure EpisodeProgress entity
            modelBuilder.Entity<EpisodeProgress>(entity =>
            {
                entity.HasKey(ep => ep.Id);
                entity.Property(ep => ep.WatchedAt).IsRequired().HasDefaultValueSql("GETUTCDATE()");
                
                // One user can only have one progress record per episode
                entity.HasIndex(ep => new { ep.UserId, ep.EpisodeId }).IsUnique();

                entity.HasOne(ep => ep.User)
                    .WithMany(u => u.EpisodeProgresses)
                    .HasForeignKey(ep => ep.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(ep => ep.Episode)
                    .WithMany(e => e.EpisodeProgresses)
                    .HasForeignKey(ep => ep.EpisodeId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Configure EpisodeReview entity
            modelBuilder.Entity<EpisodeReview>(entity =>
            {
                entity.HasKey(er => er.Id);
                entity.Property(er => er.Rating).IsRequired();
                entity.Property(er => er.ReviewText).HasMaxLength(2000);
                entity.Property(er => er.CreatedAt).IsRequired().HasDefaultValueSql("GETUTCDATE()");
                
                // One user can only have one review per episode
                entity.HasIndex(er => new { er.UserId, er.EpisodeId }).IsUnique();

                entity.HasOne(er => er.User)
                    .WithMany(u => u.EpisodeReviews)
                    .HasForeignKey(er => er.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(er => er.Episode)
                    .WithMany(e => e.EpisodeReviews)
                    .HasForeignKey(er => er.EpisodeId)
                    .OnDelete(DeleteBehavior.Cascade);
            });
        }
    }
}

