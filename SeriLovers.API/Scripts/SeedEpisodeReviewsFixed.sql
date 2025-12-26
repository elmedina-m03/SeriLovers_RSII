-- SQL Script to seed EpisodeReviews table with sample data
-- This script creates reviews for episodes, including anonymous reviews
-- Run this script in SQL Server Management Studio

-- First, check if we have users and episodes
IF NOT EXISTS (SELECT 1 FROM AspNetUsers)
BEGIN
    PRINT 'ERROR: No users found in AspNetUsers table. Please seed users first.';
    RETURN;
END

IF NOT EXISTS (SELECT 1 FROM Episodes)
BEGIN
    PRINT 'ERROR: No episodes found. Please seed series, seasons, and episodes first.';
    RETURN;
END

-- Clear existing reviews (optional - comment out if you want to keep existing reviews)
-- DELETE FROM EpisodeReviews;

-- Insert sample reviews
-- Get first 3 users and first 10 episodes
INSERT INTO EpisodeReviews (UserId, EpisodeId, Rating, ReviewText, CreatedAt, IsAnonymous)
SELECT 
    u.Id AS UserId,
    e.Id AS EpisodeId,
    -- Random rating between 3 and 5
    CAST(RAND(CHECKSUM(NEWID())) * 3 + 3 AS INT) AS Rating,
    -- Sample review texts
    CASE 
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 5 AS INT) = 0 THEN 'Great episode! Really enjoyed it.'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 5 AS INT) = 1 THEN 'Amazing storytelling and character development.'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 5 AS INT) = 2 THEN 'One of the best episodes of the season.'
        WHEN CAST(RAND(CHECKSUM(NEWID())) * 5 AS INT) = 3 THEN 'Very very very good!'
        ELSE 'Loved every minute of it!'
    END AS ReviewText,
    -- Random date within last 60 days
    DATEADD(DAY, -CAST(RAND(CHECKSUM(NEWID())) * 60 AS INT), GETUTCDATE()) AS CreatedAt,
    -- Random anonymous flag (30% anonymous)
    CASE WHEN CAST(RAND(CHECKSUM(NEWID())) * 10 AS INT) < 3 THEN 1 ELSE 0 END AS IsAnonymous
FROM 
    (SELECT TOP 3 Id FROM AspNetUsers ORDER BY Id) u
    CROSS JOIN (SELECT TOP 10 Id FROM Episodes ORDER BY Id) e
WHERE 
    -- Ensure we don't create duplicate reviews
    NOT EXISTS (
        SELECT 1 
        FROM EpisodeReviews er 
        WHERE er.UserId = u.Id AND er.EpisodeId = e.Id
    );

-- Verify the inserted data
PRINT 'Review seeding completed. Summary:';
SELECT 
    COUNT(*) AS TotalReviews,
    SUM(CASE WHEN IsAnonymous = 1 THEN 1 ELSE 0 END) AS AnonymousReviews,
    SUM(CASE WHEN IsAnonymous = 0 THEN 1 ELSE 0 END) AS NamedReviews
FROM EpisodeReviews;

-- Show sample of inserted reviews
SELECT TOP 20
    er.Id,
    u.UserName,
    CASE WHEN er.IsAnonymous = 1 THEN 'Anonymous' ELSE u.UserName END AS DisplayName,
    er.IsAnonymous,
    s.SeriesId,
    s.SeasonNumber,
    e.EpisodeNumber,
    e.Title AS EpisodeTitle,
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

