-- Manual SQL script to add Name column to AspNetUsers table
-- Run this if the migration doesn't work automatically

IF NOT EXISTS (
    SELECT 1 
    FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'[dbo].[AspNetUsers]') 
    AND name = 'Name'
)
BEGIN
    ALTER TABLE [dbo].[AspNetUsers]
    ADD [Name] NVARCHAR(MAX) NULL;
    
    PRINT 'Name column added successfully to AspNetUsers table.';
END
ELSE
BEGIN
    PRINT 'Name column already exists in AspNetUsers table.';
END

