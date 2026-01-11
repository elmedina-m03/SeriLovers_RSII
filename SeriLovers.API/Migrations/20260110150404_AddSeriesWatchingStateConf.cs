using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class AddSeriesWatchingStateConf : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Table SeriesWatchingStates was already created in migration 20260109213345_AddSeriesWatchingStates
            // This migration is a no-op to maintain migration history
            // If table doesn't exist, it will be created by the previous migration
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SeriesWatchingStates");
        }
    }
}
