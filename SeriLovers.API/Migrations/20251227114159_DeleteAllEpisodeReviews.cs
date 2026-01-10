using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class DeleteAllEpisodeReviews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Delete all EpisodeReview records
            // Reviews are now ONLY allowed for entire SERIES, not individual episodes
            migrationBuilder.Sql(@"
                DELETE FROM EpisodeReviews;
            ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Cannot restore deleted data - this is a one-way data cleanup operation
            // No rollback possible
        }
    }
}

