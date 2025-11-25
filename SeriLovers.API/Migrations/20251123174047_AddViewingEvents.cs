using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class AddViewingEvents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ViewingEvents",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    UserId = table.Column<int>(type: "int", nullable: false),
                    SeriesId = table.Column<int>(type: "int", nullable: false),
                    ViewedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ViewingEvents", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ViewingEvents_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_ViewingEvents_Series_SeriesId",
                        column: x => x.SeriesId,
                        principalTable: "Series",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ViewingEvents_SeriesId",
                table: "ViewingEvents",
                column: "SeriesId");

            migrationBuilder.CreateIndex(
                name: "IX_ViewingEvents_UserId_SeriesId_ViewedAt",
                table: "ViewingEvents",
                columns: new[] { "UserId", "SeriesId", "ViewedAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ViewingEvents");
        }
    }
}
