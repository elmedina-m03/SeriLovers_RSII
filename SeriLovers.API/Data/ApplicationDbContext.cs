using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.Extensions.Logging;
using SeriLovers.API.Models;
using System.Linq;

namespace SeriLovers.API.Data
{
    public class ApplicationDbContext : IdentityDbContext<ApplicationUser, IdentityRole<int>, int>
    {
        private readonly ILogger<ApplicationDbContext>? _logger;

        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options, ILogger<ApplicationDbContext> logger)
            : base(options)
        {
            _logger = logger;
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
        public DbSet<SeriesWatchingState> SeriesWatchingStates { get; set; }
        public DbSet<UserSeriesReminder> UserSeriesReminders { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

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

            modelBuilder.Entity<Actor>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.FirstName).IsRequired().HasMaxLength(100);
                entity.Property(e => e.LastName).IsRequired().HasMaxLength(100);
                entity.Property(e => e.Biography).HasMaxLength(2000);
            });

            modelBuilder.Entity<Genre>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
                entity.HasIndex(e => e.Name).IsUnique();
            });

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

            modelBuilder.Entity<WatchlistCollection>(entity =>
            {
                entity.HasKey(wc => wc.Id);
                entity.Property(wc => wc.Name).IsRequired().HasMaxLength(100);
                entity.Property(wc => wc.Description).HasMaxLength(500);
                entity.Property(wc => wc.CreatedAt).HasDefaultValueSql("GETUTCDATE()");
                entity.HasIndex(wc => new { wc.UserId, wc.Name }).IsUnique();
                entity.HasOne(wc => wc.User)
                    .WithMany()
                    .HasForeignKey(wc => wc.UserId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<Watchlist>(entity =>
            {
                entity.HasKey(w => w.Id);
                entity.Property(w => w.AddedAt).HasDefaultValueSql("GETUTCDATE()");
                entity.HasIndex(w => new { w.UserId, w.SeriesId, w.CollectionId }).IsUnique();

                entity.HasOne(w => w.User)
                    .WithMany(u => u.Watchlists)
                    .HasForeignKey(w => w.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(w => w.Series)
                    .WithMany(s => s.Watchlists)
                    .HasForeignKey(w => w.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
                
                entity.HasOne(w => w.Collection)
                    .WithMany(c => c.Watchlists)
                    .HasForeignKey(w => w.CollectionId)
                    .OnDelete(DeleteBehavior.NoAction);
            });

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

            modelBuilder.Entity<ChallengeProgress>(entity =>
            {
                entity.ToTable("ChallengeProgresses");
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

            modelBuilder.Entity<EpisodeProgress>(entity =>
            {
                entity.HasKey(ep => ep.Id);
                entity.Property(ep => ep.WatchedAt).IsRequired().HasDefaultValueSql("GETUTCDATE()");
                
                // IsCompleted should always be true - incomplete records should not exist
                // This is enforced at application level, but we set default to true
                entity.Property(ep => ep.IsCompleted)
                    .IsRequired()
                    .HasDefaultValue(true)
                    .ValueGeneratedNever(); // Don't let database generate values - we control it
                
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

            modelBuilder.Entity<SeriesWatchingState>(entity =>
            {
                entity.HasKey(sws => sws.Id);
                entity.Property(sws => sws.Status).IsRequired();
                entity.Property(sws => sws.WatchedEpisodesCount).IsRequired().HasDefaultValue(0);
                entity.Property(sws => sws.TotalEpisodesCount).IsRequired().HasDefaultValue(0);
                entity.Property(sws => sws.CreatedAt).IsRequired().HasDefaultValueSql("GETUTCDATE()");
                entity.Property(sws => sws.LastUpdated).IsRequired().HasDefaultValueSql("GETUTCDATE()");
                
                // One user can only have one watching state per series
                entity.HasIndex(sws => new { sws.UserId, sws.SeriesId }).IsUnique();

                entity.HasOne(sws => sws.User)
                    .WithMany()
                    .HasForeignKey(sws => sws.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(sws => sws.Series)
                    .WithMany()
                    .HasForeignKey(sws => sws.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<UserSeriesReminder>(entity =>
            {
                entity.HasKey(usr => usr.Id);
                entity.Property(usr => usr.EnabledAt).IsRequired().HasDefaultValueSql("GETUTCDATE()");
                entity.Property(usr => usr.LastEpisodeCount).IsRequired().HasDefaultValue(0);
                
                // One user can only have one reminder per series
                entity.HasIndex(usr => new { usr.UserId, usr.SeriesId }).IsUnique();

                entity.HasOne(usr => usr.User)
                    .WithMany(u => u.UserSeriesReminders)
                    .HasForeignKey(usr => usr.UserId)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(usr => usr.Series)
                    .WithMany()
                    .HasForeignKey(usr => usr.SeriesId)
                    .OnDelete(DeleteBehavior.Cascade);
            });
        }

        public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            // Prevent creating or updating EpisodeProgress records with IsCompleted = false
            var episodeProgressEntries = ChangeTracker.Entries<EpisodeProgress>()
                .Where(e => e.State == EntityState.Added || e.State == EntityState.Modified)
                .ToList();

            foreach (var entry in episodeProgressEntries)
            {
                // Ensure IsCompleted is always true - incomplete records should not exist
                if (!entry.Entity.IsCompleted)
                {
                    _logger?.LogWarning("Attempted to save EpisodeProgress with IsCompleted=false. EpisodeId={EpisodeId}, UserId={UserId}, State={State}. Setting to true or removing.",
                        entry.Entity.EpisodeId, entry.Entity.UserId, entry.State);

                    if (entry.State == EntityState.Added)
                    {
                        // Don't create incomplete records - mark as complete instead
                        entry.Entity.IsCompleted = true;
                    }
                    else if (entry.State == EntityState.Modified)
                    {
                        // If trying to update to incomplete, delete the record instead
                        entry.State = EntityState.Deleted;
                        _logger?.LogInformation("Deleting EpisodeProgress record instead of setting IsCompleted=false. EpisodeId={EpisodeId}, UserId={UserId}",
                            entry.Entity.EpisodeId, entry.Entity.UserId);
                    }
                }
                else
                {
                    // Ensure IsCompleted is explicitly set to true (in case it's default/uninitialized)
                    entry.Entity.IsCompleted = true;
                }
            }

            return await base.SaveChangesAsync(cancellationToken);
        }
    }
}

