# Database Seeding Guide

## How to Get Real Data in Your Application

The SeriLovers API already has a database seeder that automatically populates your database with sample data when running in **Development** mode.

### Automatic Seeding

The database is automatically seeded when you start the API in Development mode. The seeding happens in `Program.cs`:

```csharp
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var services = scope.ServiceProvider;
    await DbSeeder.Seed(services);
}
```

### What Gets Seeded

The `DbSeeder` class seeds the following data:

1. **Roles**: Admin, User
2. **Genres**: Various TV show genres
3. **Actors**: Popular actors (Bryan Cranston, Emilia Clarke, Kit Harington, etc.)
4. **Series**: Popular TV series including:
   - Breaking Bad
   - Game of Thrones
   - The Office
   - The Crown
   - Friends
   - And more...
5. **Users**: Test users (if none exist)
6. **Watchlists**: Sample watchlist entries
7. **Ratings**: Sample ratings and reviews
8. **Challenges**: Sample challenges
9. **Challenge Progress**: User progress on challenges

### How to Ensure Data is Seeded

1. **Make sure you're running in Development mode:**
   - Check your `appsettings.Development.json` or environment variables
   - The API should be running with `ASPNETCORE_ENVIRONMENT=Development`

2. **Start the API:**
   ```bash
   cd SeriLovers.API
   dotnet run
   ```

3. **Check the database:**
   - The seeder checks if data already exists before seeding
   - If your database is empty, it will populate it
   - If data already exists, it will skip seeding (to avoid duplicates)

### Manual Seeding (If Needed)

If you want to force re-seeding or seed in Production:

1. **Option 1: Clear the database and restart**
   - Delete your database or run migrations to reset it
   - Restart the API in Development mode

2. **Option 2: Modify the seeder**
   - Edit `SeriLovers.API/Data/DbSeeder.cs`
   - Remove the checks that prevent re-seeding (e.g., `if (await context.Series.AnyAsync())`)
   - Restart the API

3. **Option 3: Create a seeding endpoint (for development)**
   - Add a controller endpoint that calls `DbSeeder.Seed()`
   - Call it manually when needed

### Adding More Sample Data

To add more series, actors, or other data:

1. Edit `SeriLovers.API/Data/DbSeeder.cs`
2. Add entries to the seed arrays (e.g., `seriesSeeds`, `actors`)
3. Restart the API

### Example: Adding a New Series

```csharp
new SeriesSeedDefinition(
    "Your Series Title",
    "Description of the series",
    new DateTime(2020, 1, 1), // Release date
    "Drama", // Primary genre
    8.5, // Rating
    new[] { "Drama", "Thriller" }, // Genres
    new[]
    {
        ("Actor", "First", "Character Name"),
        ("Actor", "Second", "Another Character")
    },
    SeasonsToEnsure: 3 // Number of seasons
)
```

### Troubleshooting

**No data appears:**
- Check if the API is running in Development mode
- Check database connection string
- Verify migrations have been applied
- Check API logs for seeding errors

**Duplicate data:**
- The seeder checks for existing data and skips if found
- To re-seed, clear the database first

**Missing images:**
- Series images are stored in `ImageUrl` field
- You may need to add image URLs to the seed data
- Or use placeholder images

### Current Seed Data Includes

- **~10+ Series** with full details
- **~20+ Actors** with biographies
- **Multiple Genres** (Drama, Comedy, Crime, Fantasy, etc.)
- **Sample Users** for testing
- **Watchlist Collections** and entries
- **Ratings and Reviews**
- **Challenges** with progress tracking

The seed data provides a good starting point for testing and development!

