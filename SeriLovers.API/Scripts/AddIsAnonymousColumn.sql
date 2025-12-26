-- Add IsAnonymous column to EpisodeReviews table if it doesn't exist
IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'[dbo].[EpisodeReviews]') 
    AND name = 'IsAnonymous'
)
BEGIN
    ALTER TABLE [dbo].[EpisodeReviews]
    ADD [IsAnonymous] BIT NOT NULL DEFAULT 0;
    
    PRINT 'IsAnonymous column added successfully to EpisodeReviews table.';
END
ELSE
BEGIN
    PRINT 'IsAnonymous column already exists in EpisodeReviews table.';
END
GO

