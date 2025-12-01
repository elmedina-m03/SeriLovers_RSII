using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class AddEpisodeProgressAndReviews : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Watchlists_WatchlistCollections_CollectionId",
                table: "Watchlists");

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

            migrationBuilder.AddColumn<string>(
                name: "Category",
                table: "WatchlistCollections",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CoverUrl",
                table: "WatchlistCollections",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "WatchlistCollections",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "EpisodeProgresses",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    EpisodeId = table.Column<int>(type: "int", nullable: false),
                    WatchedAt = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()"),
                    IsCompleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EpisodeProgresses", x => x.Id);
                    table.ForeignKey(
                        name: "FK_EpisodeProgresses_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_EpisodeProgresses_Episodes_EpisodeId",
                        column: x => x.EpisodeId,
                        principalTable: "Episodes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "EpisodeReviews",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    EpisodeId = table.Column<int>(type: "int", nullable: false),
                    Rating = table.Column<int>(type: "int", nullable: false),
                    ReviewText = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EpisodeReviews", x => x.Id);
                    table.ForeignKey(
                        name: "FK_EpisodeReviews_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_EpisodeReviews_Episodes_EpisodeId",
                        column: x => x.EpisodeId,
                        principalTable: "Episodes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_WatchlistCollections_UserId",
                table: "WatchlistCollections",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_EpisodeProgresses_EpisodeId",
                table: "EpisodeProgresses",
                column: "EpisodeId");

            migrationBuilder.CreateIndex(
                name: "IX_EpisodeProgresses_UserId_EpisodeId",
                table: "EpisodeProgresses",
                columns: new[] { "UserId", "EpisodeId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_EpisodeReviews_EpisodeId",
                table: "EpisodeReviews",
                column: "EpisodeId");

            migrationBuilder.CreateIndex(
                name: "IX_EpisodeReviews_UserId_EpisodeId",
                table: "EpisodeReviews",
                columns: new[] { "UserId", "EpisodeId" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Watchlists_WatchlistCollections_CollectionId",
                table: "Watchlists",
                column: "CollectionId",
                principalTable: "WatchlistCollections",
                principalColumn: "Id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Watchlists_WatchlistCollections_CollectionId",
                table: "Watchlists");

            migrationBuilder.DropTable(
                name: "EpisodeProgresses");

            migrationBuilder.DropTable(
                name: "EpisodeReviews");

            migrationBuilder.DropIndex(
                name: "IX_WatchlistCollections_UserId",
                table: "WatchlistCollections");

            migrationBuilder.DropColumn(
                name: "Category",
                table: "WatchlistCollections");

            migrationBuilder.DropColumn(
                name: "CoverUrl",
                table: "WatchlistCollections");

            migrationBuilder.DropColumn(
                name: "Status",
                table: "WatchlistCollections");

            migrationBuilder.AlterColumn<DateTime>(
                name: "CreatedAt",
                table: "WatchlistCollections",
                type: "datetime2",
                nullable: false,
                defaultValueSql: "GETUTCDATE()",
                oldClrType: typeof(DateTime),
                oldType: "datetime2");

            migrationBuilder.CreateIndex(
                name: "IX_WatchlistCollections_UserId_Name",
                table: "WatchlistCollections",
                columns: new[] { "UserId", "Name" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Watchlists_WatchlistCollections_CollectionId",
                table: "Watchlists",
                column: "CollectionId",
                principalTable: "WatchlistCollections",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }
    }
}
