-- SQL Script to seed EpisodeReviews table with sample data
-- Run this script in SQL Server Management Studio after ensuring you have:
-- 1. Users in AspNetUsers table
-- 2. Series with Seasons and Episodes

-- Example: Insert sample reviews
-- Replace UserId and EpisodeId values with actual IDs from your database

-- First, let's get some sample data
-- You can run these queries to see available data:
-- SELECT TOP 5 Id, UserName, Email FROM AspNetUsers;
-- SELECT TOP 5 e.Id, e.Title, e.EpisodeNumber, s.SeasonNumber, s.SeriesId 
-- FROM Episodes e 
-- INNER JOIN Seasons s ON e.SeasonId = s.Id;

-- Insert sample reviews (adjust UserId and EpisodeId based on your data)
INSERT INTO EpisodeReviews (UserId, EpisodeId, Rating, ReviewText, CreatedAt, IsAnonymous)
SELECT 
    u.Id AS UserId,
    e.Id AS EpisodeId,
    -- Random rating between 3 and 5
    CAST(RAND(CHECKSUM(NEWID())) * 3 + 3 AS INT) AS Rating,
    -- Sample review texts
    CASE 
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 4 AS INT) = 0 THEN 'Great episode! Really enjoyed it.'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 4 AS INT) = 1 THEN 'Amazing storytelling and character development.'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 4 AS INT) = 2 THEN 'One of the best episodes of the season.'
        ELSE 'Loved every minute of it!'
    END AS ReviewText,
    -- Random date within last 30 days
    DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 30 AS INT), GETUTCDATE()) AS CreatedAt,
    -- Random anonymous flag (20% anonymous)
    CASE WHEN CAST(RAND(CHECKSUM(NEWID())) * 5 AS INT) = 0 THEN 1 ELSE 0 END AS IsAnonymous
FROM 
    AspNetUsers u
    CROSS JOIN Episodes e
    INNER JOIN Seasons s ON e.SeasonId = s.Id
WHERE 
    -- Limit to first 3 users and first 10 episodes to avoid too many reviews
    u.Id IN (SELECT TOP 3 Id FROM AspNetUsers ORDER BY Id)
    AND e.Id IN (SELECT TOP 10 Id FROM Episodes ORDER BY Id)
    -- Ensure we don't create duplicate reviews
    AND NOT EXISTS (
        SELECT 1 
        FROM EpisodeReviews er 
        WHERE er.UserId = u.Id AND er.EpisodeId = e.Id
    );

-- Verify the inserted data
SELECT 
    er.Id,
    u.UserName,
    er.IsAnonymous,
    s.SeriesId,
    s.SeasonNumber,
    e.EpisodeNumber,
    er.Rating,
    er.ReviewText,
    er.CreatedAt
FROM 
    EpisodeReviews er
    INNER JOIN AspNetUsers u ON er.UserId = u.Id
    INNER JOIN Episodes e ON er.EpisodeId = e.Id
    INNER JOIN Seasons s ON e.SeasonId = s.Id
ORDER BY 
    er.CreatedAt DESC;

