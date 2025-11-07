using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class AddSeriesRelations : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_SeriesActors_Actors_ActorsId",
                table: "SeriesActors");

            migrationBuilder.DropForeignKey(
                name: "FK_SeriesGenres_Genres_GenresId",
                table: "SeriesGenres");

            migrationBuilder.DropPrimaryKey(
                name: "PK_SeriesGenres",
                table: "SeriesGenres");

            migrationBuilder.DropIndex(
                name: "IX_SeriesGenres_SeriesId",
                table: "SeriesGenres");

            migrationBuilder.DropPrimaryKey(
                name: "PK_SeriesActors",
                table: "SeriesActors");

            migrationBuilder.DropIndex(
                name: "IX_SeriesActors_SeriesId",
                table: "SeriesActors");

            migrationBuilder.RenameColumn(
                name: "GenresId",
                table: "SeriesGenres",
                newName: "GenreId");

            migrationBuilder.RenameColumn(
                name: "ActorsId",
                table: "SeriesActors",
                newName: "ActorId");

            migrationBuilder.AddColumn<string>(
                name: "RoleName",
                table: "SeriesActors",
                type: "nvarchar(150)",
                maxLength: 150,
                nullable: true);

            migrationBuilder.AddPrimaryKey(
                name: "PK_SeriesGenres",
                table: "SeriesGenres",
                columns: new[] { "SeriesId", "GenreId" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_SeriesActors",
                table: "SeriesActors",
                columns: new[] { "SeriesId", "ActorId" });

            migrationBuilder.CreateIndex(
                name: "IX_SeriesGenres_GenreId",
                table: "SeriesGenres",
                column: "GenreId");

            migrationBuilder.CreateIndex(
                name: "IX_SeriesActors_ActorId",
                table: "SeriesActors",
                column: "ActorId");

            migrationBuilder.AddForeignKey(
                name: "FK_SeriesActors_Actors_ActorId",
                table: "SeriesActors",
                column: "ActorId",
                principalTable: "Actors",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_SeriesGenres_Genres_GenreId",
                table: "SeriesGenres",
                column: "GenreId",
                principalTable: "Genres",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_SeriesActors_Actors_ActorId",
                table: "SeriesActors");

            migrationBuilder.DropForeignKey(
                name: "FK_SeriesGenres_Genres_GenreId",
                table: "SeriesGenres");

            migrationBuilder.DropPrimaryKey(
                name: "PK_SeriesGenres",
                table: "SeriesGenres");

            migrationBuilder.DropIndex(
                name: "IX_SeriesGenres_GenreId",
                table: "SeriesGenres");

            migrationBuilder.DropPrimaryKey(
                name: "PK_SeriesActors",
                table: "SeriesActors");

            migrationBuilder.DropIndex(
                name: "IX_SeriesActors_ActorId",
                table: "SeriesActors");

            migrationBuilder.DropColumn(
                name: "RoleName",
                table: "SeriesActors");

            migrationBuilder.RenameColumn(
                name: "GenreId",
                table: "SeriesGenres",
                newName: "GenresId");

            migrationBuilder.RenameColumn(
                name: "ActorId",
                table: "SeriesActors",
                newName: "ActorsId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_SeriesGenres",
                table: "SeriesGenres",
                columns: new[] { "GenresId", "SeriesId" });

            migrationBuilder.AddPrimaryKey(
                name: "PK_SeriesActors",
                table: "SeriesActors",
                columns: new[] { "ActorsId", "SeriesId" });

            migrationBuilder.CreateIndex(
                name: "IX_SeriesGenres_SeriesId",
                table: "SeriesGenres",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_SeriesActors_SeriesId",
                table: "SeriesActors",
                column: "SeriesId");

            migrationBuilder.AddForeignKey(
                name: "FK_SeriesActors_Actors_ActorsId",
                table: "SeriesActors",
                column: "ActorsId",
                principalTable: "Actors",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_SeriesGenres_Genres_GenresId",
                table: "SeriesGenres",
                column: "GenresId",
                principalTable: "Genres",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
