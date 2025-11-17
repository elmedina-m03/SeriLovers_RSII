using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class AddFavoriteCharacterAndRecommendationLog : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "FavoriteCharacters",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    ActorId = table.Column<int>(type: "int", nullable: false),
                    SeriesId = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FavoriteCharacters", x => x.Id);
                    table.ForeignKey(
                        name: "FK_FavoriteCharacters_Actors_ActorId",
                        column: x => x.ActorId,
                        principalTable: "Actors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_FavoriteCharacters_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_FavoriteCharacters_Series_SeriesId",
                        column: x => x.SeriesId,
                        principalTable: "Series",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "RecommendationLogs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    SeriesId = table.Column<int>(type: "int", nullable: false),
                    RecommendedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Watched = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RecommendationLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_RecommendationLogs_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_RecommendationLogs_Series_SeriesId",
                        column: x => x.SeriesId,
                        principalTable: "Series",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_FavoriteCharacters_ActorId",
                table: "FavoriteCharacters",
                column: "ActorId");

            migrationBuilder.CreateIndex(
                name: "IX_FavoriteCharacters_SeriesId",
                table: "FavoriteCharacters",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_FavoriteCharacters_UserId_ActorId_SeriesId",
                table: "FavoriteCharacters",
                columns: new[] { "UserId", "ActorId", "SeriesId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationLogs_SeriesId",
                table: "RecommendationLogs",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_RecommendationLogs_UserId_SeriesId_RecommendedAt",
                table: "RecommendationLogs",
                columns: new[] { "UserId", "SeriesId", "RecommendedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "FavoriteCharacters");

            migrationBuilder.DropTable(
                name: "RecommendationLogs");
        }
    }
}
