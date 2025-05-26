##Creating Table

CREATE TABLE AnonSpotifyHistory (
    Id INT AUTO_INCREMENT,
     ts VARCHAR(100),
     platform VARCHAR(100),
	ms_played BIGINT,
     track_name LONGTEXT,
     artist_name LONGTEXT,
     album_name LONGTEXT,
     reason_start VARCHAR(100),
     reason_end VARCHAR(100),
     shuffle VARCHAR(100),
     skipped LONGTEXT,
     
    PRIMARY KEY (Id)
    );

##Loading File

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/anon_spotify_history_cleaned.csv'
INTO TABLE portfolio_projects.AnonSpotifyHistory
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ts, platform, ms_played, track_name, artist_name, album_name, reason_start, reason_end, shuffle,  skipped );  -- Excluding `id`;

##Exploring the data
SELECT *
FROM anonSpotifyHistory;

##Separating time and date
ALTER TABLE anonSpotifyHistory 
ADD COLUMN date_only DATE, 
ADD COLUMN time_only TIME;

UPDATE anonSpotifyHistory
SET 
    date_only = STR_TO_DATE(SUBSTRING_INDEX(ts, ' ', 1), '%m/%d/%Y'),
    time_only = STR_TO_DATE(SUBSTRING_INDEX(ts, ' ', -1), '%k:%i');

##Most listened artist CURRENT year
SELECT artist_name, YEAR(date_only) AS Year_, SUM(ms_played) AS total_ms
FROM AnonSpotifyHistory
WHERE YEAR(date_only) = (
    SELECT MAX(YEAR(date_only)) FROM AnonSpotifyHistory
)
GROUP BY artist_name, Year_
ORDER BY total_ms DESC
LIMIT 1;

##Most listened artist PREVIOUS year
SELECT artist_name, YEAR(date_only) AS Year_, SUM(ms_played) AS total_ms
FROM AnonSpotifyHistory
WHERE YEAR(date_only) = (
    SELECT MAX(YEAR(date_only))-1 FROM AnonSpotifyHistory
)
GROUP BY artist_name, Year_
ORDER BY total_ms DESC
LIMIT 1;

##Most played songs and how often they are skipped
SELECT 
    track_name,
    artist_name,
    COUNT(*) AS play_count,
    SUM(CASE WHEN skipped = TRUE THEN 1 ELSE 0 END) AS skip_count,
    ROUND(SUM(CASE WHEN skipped = TRUE THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS skip_rate_percent
FROM AnonSpotifyHistory
GROUP BY track_name, artist_name
ORDER BY play_count DESC
LIMIT 10;

##What time of day do they typically listen to music?

SELECT
    CASE 
        WHEN HOUR(time_only) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN HOUR(time_only) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN HOUR(time_only) BETWEEN 17 AND 21 THEN 'Evening'
        ELSE 'Night'
    END AS time_of_day,
    COUNT(*) AS plays,
    RANK () OVER ( ORDER BY COUNT(*) DESC) AS Rank_
FROM AnonSpotifyHistory
GROUP BY time_of_day
ORDER BY plays DESC;

##How often do they explore new artists vs replaying favorites?

WITH FirstListens AS (
    SELECT 
        artist_name,
        MIN(date_only) AS first_time
    FROM AnonSpotifyHistory
    GROUP BY artist_name
),

TopArtists AS (
    SELECT 
        artist_name,
        COUNT(*) AS total_plays
    FROM AnonSpotifyHistory
    GROUP BY artist_name
    ORDER BY total_plays DESC
    LIMIT 20
),

AllPlays AS (
    SELECT 
        a.artist_name,
        a.date_only AS played_at,
        f.first_time
    FROM AnonSpotifyHistory a
    JOIN FirstListens f ON a.artist_name = f.artist_name
),
	
ClassifiedPlays AS (
    SELECT
        p.artist_name,
        p.played_at,
        p.first_time,
        CASE 
            WHEN p.played_at = p.first_time THEN 'New Artist'
            WHEN t.artist_name IS NOT NULL THEN 'Favorite Replay'
            ELSE 'Other Replay'
        END AS artist_type
    FROM AllPlays p
    LEFT JOIN TopArtists t ON p.artist_name = t.artist_name
),

Counts AS (
    SELECT
        artist_type,
        COUNT(*) AS play_count
    FROM ClassifiedPlays
    WHERE artist_type IN ('New Artist', 'Favorite Replay')
    GROUP BY artist_type
),

Total AS (
    SELECT SUM(play_count) AS total_plays
    FROM Counts
)

SELECT
    c.artist_type,
    c.play_count,
    ROUND(100.0 * c.play_count / t.total_plays, 2) AS percentage
FROM Counts c
CROSS JOIN Total t;

##Final check
SELECT *
FROM anonSpotifyHistory;
