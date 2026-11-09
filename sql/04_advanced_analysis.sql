-- Advanced questions with a business purpose. All rankings are based on
-- supplied totals and labels; no date-based window is possible in this schema.

-- Q1. Within each artist, how do the top viewed artist/track/album labels rank?
-- ROW_NUMBER selects a deterministic row order; RANK leaves gaps after ties;
-- DENSE_RANK does not. PARTITION BY restarts each ranking for each artist.
WITH track_views AS (
    SELECT artist, track, album, SUM(views) AS total_views
    FROM spotify
    GROUP BY artist, track, album
),
ranked AS (
    SELECT
        artist,
        track,
        album,
        total_views,
        ROW_NUMBER() OVER (
            PARTITION BY artist
            ORDER BY total_views DESC NULLS LAST, track, album
        ) AS row_number_by_artist,
        RANK() OVER (
            PARTITION BY artist
            ORDER BY total_views DESC NULLS LAST
        ) AS rank_by_artist,
        DENSE_RANK() OVER (
            PARTITION BY artist
            ORDER BY total_views DESC NULLS LAST
        ) AS dense_rank_by_artist
    FROM track_views
)
SELECT *
FROM ranked
WHERE dense_rank_by_artist <= 3
ORDER BY artist, dense_rank_by_artist, row_number_by_artist;

-- Q2. For each artist, how different are the adjacent records in view rank?
-- LAG returns the preceding row and LEAD the following row in this explicit
-- sort order. They are rank neighbors, not earlier/later releases or dates.
WITH track_views AS (
    SELECT artist, track, album, SUM(views) AS total_views
    FROM spotify
    GROUP BY artist, track, album
),
ranked AS (
    SELECT
        artist,
        track,
        album,
        total_views,
        ROW_NUMBER() OVER (
            PARTITION BY artist
            ORDER BY total_views DESC NULLS LAST, track, album
        ) AS view_order,
        LAG(total_views) OVER (
            PARTITION BY artist
            ORDER BY total_views DESC NULLS LAST, track, album
        ) AS preceding_record_views,
        LEAD(total_views) OVER (
            PARTITION BY artist
            ORDER BY total_views DESC NULLS LAST, track, album
        ) AS following_record_views
    FROM track_views
)
SELECT
    artist,
    view_order,
    track,
    album,
    total_views,
    preceding_record_views,
    following_record_views,
    preceding_record_views - total_views AS gap_from_preceding_record
FROM ranked
WHERE view_order <= 3
ORDER BY artist, view_order;

-- Q3. Which artists have the largest reported stream totals and what fraction
-- of all streams do they represent? The scalar CTE returns one denominator row,
-- so the CROSS JOIN preserves the one-row-per-artist grain.
WITH per_artist AS (
    SELECT artist, SUM(stream) AS artist_streams
    FROM spotify
    GROUP BY artist
),
catalog_total AS (
    SELECT SUM(stream) AS total_streams
    FROM spotify
)
SELECT
    per_artist.artist,
    per_artist.artist_streams,
    ROUND(
        100.0 * per_artist.artist_streams / NULLIF(catalog_total.total_streams, 0),
        3
    ) AS catalog_stream_share_pct
FROM per_artist
CROSS JOIN catalog_total
ORDER BY per_artist.artist_streams DESC NULLS LAST, per_artist.artist
LIMIT 25;

-- No moving-average or time-series query is included: the dataset has no valid
-- release, observation, or snapshot date column.
