-- Spotify CSV import schema and basic PostgreSQL profiling.
-- Run from the repository root with psql. This script never drops or truncates
-- a table. To reload, use a fresh database or explicitly manage your own copy.
--
-- Import after creating the table, from the repository root:
--   \copy spotify_raw FROM 'data/raw/spotify_cleaned_dataset.csv' WITH (FORMAT csv, HEADER true)
--
-- The raw table uses text columns so the source values (including blank fields
-- and the flag value "0") remain available for inspection.

CREATE TABLE IF NOT EXISTS spotify_raw (
    artist TEXT,
    track TEXT,
    album TEXT,
    album_type TEXT,
    danceability TEXT,
    energy TEXT,
    loudness TEXT,
    speechiness TEXT,
    acousticness TEXT,
    instrumentalness TEXT,
    liveness TEXT,
    valence TEXT,
    tempo TEXT,
    duration_min TEXT,
    title TEXT,
    channel TEXT,
    views TEXT,
    likes TEXT,
    comments TEXT,
    licensed TEXT,
    official_video TEXT,
    stream TEXT,
    energy_liveness TEXT,
    most_playedon TEXT
);

-- This analysis view casts fields to useful types without changing the raw
-- import. Empty numeric values stay NULL. The source's "0" flag sentinel is
-- treated as unknown (NULL), not as an explicit FALSE value.
CREATE OR REPLACE VIEW spotify AS
SELECT
    artist,
    track,
    album,
    album_type,
    NULLIF(BTRIM(danceability), '')::DOUBLE PRECISION AS danceability,
    NULLIF(BTRIM(energy), '')::DOUBLE PRECISION AS energy,
    NULLIF(BTRIM(loudness), '')::DOUBLE PRECISION AS loudness,
    NULLIF(BTRIM(speechiness), '')::DOUBLE PRECISION AS speechiness,
    NULLIF(BTRIM(acousticness), '')::DOUBLE PRECISION AS acousticness,
    NULLIF(BTRIM(instrumentalness), '')::DOUBLE PRECISION AS instrumentalness,
    NULLIF(BTRIM(liveness), '')::DOUBLE PRECISION AS liveness,
    NULLIF(BTRIM(valence), '')::DOUBLE PRECISION AS valence,
    NULLIF(BTRIM(tempo), '')::DOUBLE PRECISION AS tempo,
    NULLIF(BTRIM(duration_min), '')::DOUBLE PRECISION AS duration_min,
    title,
    channel,
    NULLIF(BTRIM(views), '')::BIGINT AS views,
    NULLIF(BTRIM(likes), '')::BIGINT AS likes,
    NULLIF(BTRIM(comments), '')::BIGINT AS comments,
    CASE
        WHEN BTRIM(licensed) = '0' THEN NULL
        ELSE NULLIF(BTRIM(licensed), '')::BOOLEAN
    END AS licensed,
    CASE
        WHEN BTRIM(official_video) = '0' THEN NULL
        ELSE NULLIF(BTRIM(official_video), '')::BOOLEAN
    END AS official_video,
    NULLIF(BTRIM(stream), '')::BIGINT AS stream,
    NULLIF(BTRIM(energy_liveness), '')::DOUBLE PRECISION AS energy_liveness,
    most_playedon
FROM spotify_raw;

-- Profiling queries below are useful after the CSV import.

-- Raw and typed-view row counts should match.
SELECT 'spotify_raw' AS relation, COUNT(*) AS row_count FROM spotify_raw
UNION ALL
SELECT 'spotify' AS relation, COUNT(*) AS row_count FROM spotify;

-- Inspect the imported source schema and the typed analysis view.
SELECT
    table_name,
    ordinal_position,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = current_schema()
  AND table_name IN ('spotify_raw', 'spotify')
ORDER BY table_name, ordinal_position;

-- Review the imported categorical labels before relying on them in analysis.
SELECT 'album_type' AS field_name, album_type AS field_value, COUNT(*) AS row_count
FROM spotify
GROUP BY album_type
UNION ALL
SELECT 'most_playedon', most_playedon, COUNT(*)
FROM spotify
GROUP BY most_playedon
ORDER BY field_name, row_count DESC;
