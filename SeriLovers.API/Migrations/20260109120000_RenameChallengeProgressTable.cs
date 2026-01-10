using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SeriLovers.API.Migrations
{
    /// <inheritdoc />
    public partial class RenameChallengeProgressTable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            var sql = @"
                IF EXISTS (SELECT * FROM sys.tables WHERE name = 'ChallengeProgresses')
                BEGIN
                    -- Rename the table
                    EXEC sp_rename 'ChallengeProgresses', 'UserChallengeProgress';
                    
                    -- Rename primary key if it exists
                    IF EXISTS (SELECT * FROM sys.key_constraints WHERE name = 'PK_ChallengeProgresses' AND parent_object_id = OBJECT_ID('UserChallengeProgress'))
                    BEGIN
                        EXEC sp_rename 'PK_ChallengeProgresses', 'PK_UserChallengeProgress', 'OBJECT';
                    END
                    
                    -- Rename foreign keys
                    IF EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_ChallengeProgresses_AspNetUsers_UserId' AND parent_object_id = OBJECT_ID('UserChallengeProgress'))
                    BEGIN
                        EXEC sp_rename 'FK_ChallengeProgresses_AspNetUsers_UserId', 'FK_UserChallengeProgress_AspNetUsers_UserId', 'OBJECT';
                    END
                    
                    IF EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_ChallengeProgresses_Challenges_ChallengeId' AND parent_object_id = OBJECT_ID('UserChallengeProgress'))
                    BEGIN
                        EXEC sp_rename 'FK_ChallengeProgresses_Challenges_ChallengeId', 'FK_UserChallengeProgress_Challenges_ChallengeId', 'OBJECT';
                    END
                    
                    -- Rename indexes
                    IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ChallengeProgresses_ChallengeId_UserId' AND object_id = OBJECT_ID('UserChallengeProgress'))
                    BEGIN
                        EXEC sp_rename 'UserChallengeProgress.IX_ChallengeProgresses_ChallengeId_UserId', 'IX_UserChallengeProgress_ChallengeId_UserId', 'INDEX';
                    END
                    
                    IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ChallengeProgresses_UserId' AND object_id = OBJECT_ID('UserChallengeProgress'))
                    BEGIN
                        EXEC sp_rename 'UserChallengeProgress.IX_ChallengeProgresses_UserId', 'IX_UserChallengeProgress_UserId', 'INDEX';
                    END
                END
            ";
            
            migrationBuilder.Sql(sql);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Rename back to old name if needed
            var sql = @"
                IF EXISTS (SELECT * FROM sys.tables WHERE name = 'UserChallengeProgress')
                BEGIN
                    EXEC sp_rename 'UserChallengeProgress', 'ChallengeProgresses';
                END
            ";
            
            migrationBuilder.Sql(sql);
        }
    }
}

