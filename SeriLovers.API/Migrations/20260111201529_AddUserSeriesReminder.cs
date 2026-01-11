using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class AddUserSeriesReminder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_WatchlistCollections_UserId",
                table: "WatchlistCollections");

            migrationBuilder.AlterColumn<DateTime>(
                name: "CreatedAt",
                table: "WatchlistCollections",
                type: "datetime2",
                nullable: false,
                defaultValueSql: "GETUTCDATE()",
                oldClrType: typeof(DateTime),
                oldType: "datetime2");

            migrationBuilder.CreateTable(
                name: "UserSeriesReminders",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    SeriesId = table.Column<int>(type: "int", nullable: false),
                    LastEpisodeCount = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    EnabledAt = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()"),
                    LastCheckedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserSeriesReminders", x => x.Id);
                    table.ForeignKey(
                        name: "FK_UserSeriesReminders_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_UserSeriesReminders_Series_SeriesId",
                        column: x => x.SeriesId,
                        principalTable: "Series",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WatchlistCollections_UserId_Name",
                table: "WatchlistCollections",
                columns: new[] { "UserId", "Name" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserSeriesReminders_SeriesId",
                table: "UserSeriesReminders",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_UserSeriesReminders_UserId_SeriesId",
                table: "UserSeriesReminders",
                columns: new[] { "UserId", "SeriesId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserSeriesReminders");

            migrationBuilder.DropIndex(
                name: "IX_WatchlistCollections_UserId_Name",
                table: "WatchlistCollections");

            migrationBuilder.AlterColumn<DateTime>(
                name: "CreatedAt",
                table: "WatchlistCollections",
                type: "datetime2",
                nullable: false,
                oldClrType: typeof(DateTime),
                oldType: "datetime2",
                oldDefaultValueSql: "GETUTCDATE()");

            migrationBuilder.CreateIndex(
                name: "IX_WatchlistCollections_UserId",
                table: "WatchlistCollections",
                column: "UserId");
        }
    }
}
