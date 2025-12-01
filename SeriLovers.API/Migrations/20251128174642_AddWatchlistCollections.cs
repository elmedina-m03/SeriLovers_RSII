using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class AddWatchlistCollections : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Watchlists_UserId_SeriesId",
                table: "Watchlists");

            migrationBuilder.AddColumn<int>(
                name: "CollectionId",
                table: "Watchlists",
                type: "int",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "WatchlistCollections",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false, defaultValueSql: "GETUTCDATE()")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_WatchlistCollections", x => x.Id);
                    table.ForeignKey(
                        name: "FK_WatchlistCollections_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Watchlists_CollectionId",
                table: "Watchlists",
                column: "CollectionId");

            migrationBuilder.CreateIndex(
                name: "IX_Watchlists_UserId_SeriesId_CollectionId",
                table: "Watchlists",
                columns: new[] { "UserId", "SeriesId", "CollectionId" },
                unique: true,
                filter: "[CollectionId] IS NOT NULL");

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
                onDelete: ReferentialAction.NoAction);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Watchlists_WatchlistCollections_CollectionId",
                table: "Watchlists");

            migrationBuilder.DropTable(
                name: "WatchlistCollections");

            migrationBuilder.DropIndex(
                name: "IX_Watchlists_CollectionId",
                table: "Watchlists");

            migrationBuilder.DropIndex(
                name: "IX_Watchlists_UserId_SeriesId_CollectionId",
                table: "Watchlists");

            migrationBuilder.DropColumn(
                name: "CollectionId",
                table: "Watchlists");

            migrationBuilder.CreateIndex(
                name: "IX_Watchlists_UserId_SeriesId",
                table: "Watchlists",
                columns: new[] { "UserId", "SeriesId" },
                unique: true);
        }
    }
}
