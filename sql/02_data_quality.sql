-- Reproducible, read-only data-quality checks for the imported dataset.
-- Run after sql/01_schema_and_profiling.sql and the CSV import.
-- Findings are surfaced for review; this script does not delete or update rows.

-- 1. Counts: source rows and typed analysis rows must agree.
SELECT
    (SELECT COUNT(*) FROM spotify_raw) AS raw_row_count,
    (SELECT COUNT(*) FROM spotify) AS analysis_row_count,
    (SELECT COUNT(*) FROM spotify_raw) = (SELECT COUNT(*) FROM spotify) AS counts_match;

-- 2. Column names and PostgreSQL data types for both relations.
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

-- 2b. Distinct non-NULL values by analysis-view column.
SELECT 'artist' AS column_name, COUNT(DISTINCT artist) AS distinct_values FROM spotify
UNION ALL SELECT 'track', COUNT(DISTINCT track) FROM spotify
UNION ALL SELECT 'album', COUNT(DISTINCT album) FROM spotify
UNION ALL SELECT 'album_type', COUNT(DISTINCT album_type) FROM spotify
UNION ALL SELECT 'danceability', COUNT(DISTINCT danceability) FROM spotify
UNION ALL SELECT 'energy', COUNT(DISTINCT energy) FROM spotify
UNION ALL SELECT 'loudness', COUNT(DISTINCT loudness) FROM spotify
UNION ALL SELECT 'speechiness', COUNT(DISTINCT speechiness) FROM spotify
UNION ALL SELECT 'acousticness', COUNT(DISTINCT acousticness) FROM spotify
UNION ALL SELECT 'instrumentalness', COUNT(DISTINCT instrumentalness) FROM spotify
UNION ALL SELECT 'liveness', COUNT(DISTINCT liveness) FROM spotify
UNION ALL SELECT 'valence', COUNT(DISTINCT valence) FROM spotify
UNION ALL SELECT 'tempo', COUNT(DISTINCT tempo) FROM spotify
UNION ALL SELECT 'duration_min', COUNT(DISTINCT duration_min) FROM spotify
UNION ALL SELECT 'title', COUNT(DISTINCT title) FROM spotify
UNION ALL SELECT 'channel', COUNT(DISTINCT channel) FROM spotify
UNION ALL SELECT 'views', COUNT(DISTINCT views) FROM spotify
UNION ALL SELECT 'likes', COUNT(DISTINCT likes) FROM spotify
UNION ALL SELECT 'comments', COUNT(DISTINCT comments) FROM spotify
UNION ALL SELECT 'licensed', COUNT(DISTINCT licensed) FROM spotify
UNION ALL SELECT 'official_video', COUNT(DISTINCT official_video) FROM spotify
UNION ALL SELECT 'stream', COUNT(DISTINCT stream) FROM spotify
UNION ALL SELECT 'energy_liveness', COUNT(DISTINCT energy_liveness) FROM spotify
UNION ALL SELECT 'most_playedon', COUNT(DISTINCT most_playedon) FROM spotify
ORDER BY distinct_values DESC, column_name;

-- 3. NULL/blank values in each typed-view field. For flags, the source value
-- "0" is mapped to NULL by the view because its meaning is undocumented.
SELECT 'artist' AS column_name, COUNT(*) FILTER (WHERE artist IS NULL OR BTRIM(artist) = '') AS missing_count FROM spotify
UNION ALL SELECT 'track', COUNT(*) FILTER (WHERE track IS NULL OR BTRIM(track) = '') FROM spotify
UNION ALL SELECT 'album', COUNT(*) FILTER (WHERE album IS NULL OR BTRIM(album) = '') FROM spotify
UNION ALL SELECT 'album_type', COUNT(*) FILTER (WHERE album_type IS NULL OR BTRIM(album_type) = '') FROM spotify
UNION ALL SELECT 'danceability', COUNT(*) FILTER (WHERE danceability IS NULL) FROM spotify
UNION ALL SELECT 'energy', COUNT(*) FILTER (WHERE energy IS NULL) FROM spotify
UNION ALL SELECT 'loudness', COUNT(*) FILTER (WHERE loudness IS NULL) FROM spotify
UNION ALL SELECT 'speechiness', COUNT(*) FILTER (WHERE speechiness IS NULL) FROM spotify
UNION ALL SELECT 'acousticness', COUNT(*) FILTER (WHERE acousticness IS NULL) FROM spotify
UNION ALL SELECT 'instrumentalness', COUNT(*) FILTER (WHERE instrumentalness IS NULL) FROM spotify
UNION ALL SELECT 'liveness', COUNT(*) FILTER (WHERE liveness IS NULL) FROM spotify
UNION ALL SELECT 'valence', COUNT(*) FILTER (WHERE valence IS NULL) FROM spotify
UNION ALL SELECT 'tempo', COUNT(*) FILTER (WHERE tempo IS NULL) FROM spotify
UNION ALL SELECT 'duration_min', COUNT(*) FILTER (WHERE duration_min IS NULL) FROM spotify
UNION ALL SELECT 'title', COUNT(*) FILTER (WHERE title IS NULL OR BTRIM(title) = '') FROM spotify
UNION ALL SELECT 'channel', COUNT(*) FILTER (WHERE channel IS NULL OR BTRIM(channel) = '') FROM spotify
UNION ALL SELECT 'views', COUNT(*) FILTER (WHERE views IS NULL) FROM spotify
UNION ALL SELECT 'likes', COUNT(*) FILTER (WHERE likes IS NULL) FROM spotify
UNION ALL SELECT 'comments', COUNT(*) FILTER (WHERE comments IS NULL) FROM spotify
UNION ALL SELECT 'licensed', COUNT(*) FILTER (WHERE licensed IS NULL) FROM spotify
UNION ALL SELECT 'official_video', COUNT(*) FILTER (WHERE official_video IS NULL) FROM spotify
UNION ALL SELECT 'stream', COUNT(*) FILTER (WHERE stream IS NULL) FROM spotify
UNION ALL SELECT 'energy_liveness', COUNT(*) FILTER (WHERE energy_liveness IS NULL) FROM spotify
UNION ALL SELECT 'most_playedon', COUNT(*) FILTER (WHERE most_playedon IS NULL OR BTRIM(most_playedon) = '') FROM spotify
ORDER BY missing_count DESC, column_name;

-- 4. Exact duplicate source rows. The excess-row count is zero when every full
-- 24-column source row is unique.
WITH duplicate_groups AS (
    SELECT COUNT(*) AS rows_per_group
    FROM spotify_raw
    GROUP BY
        artist, track, album, album_type, danceability, energy, loudness,
        speechiness, acousticness, instrumentalness, liveness, valence, tempo,
        duration_min, title, channel, views, likes, comments, licensed,
        official_video, stream, energy_liveness, most_playedon
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(rows_per_group - 1), 0) AS exact_duplicate_excess_rows
FROM duplicate_groups;

-- Repeated labels are not automatically duplicates: the source has no track
-- ID, and rows may describe different album or video records. Normalize case
-- and surrounding spaces only for this check; do not rewrite source labels.
SELECT
    MIN(artist) AS sample_artist_label,
    MIN(track) AS sample_track_label,
    COUNT(DISTINCT artist) AS artist_label_variants,
    COUNT(DISTINCT track) AS track_label_variants,
    COUNT(*) AS source_rows
FROM spotify
GROUP BY LOWER(BTRIM(artist)), LOWER(BTRIM(track))
HAVING COUNT(*) > 1
ORDER BY source_rows DESC, sample_artist_label, sample_track_label
LIMIT 100;

-- Surface case/whitespace variants in common categorical labels. The
-- normalized label is for comparison only; the raw spelling is preserved.
WITH label_values AS (
    SELECT 'artist' AS field_name, artist AS raw_label, COUNT(*) AS source_rows
    FROM spotify_raw GROUP BY artist
    UNION ALL
    SELECT 'track', track, COUNT(*) FROM spotify_raw GROUP BY track
    UNION ALL
    SELECT 'album', album, COUNT(*) FROM spotify_raw GROUP BY album
    UNION ALL
    SELECT 'album_type', album_type, COUNT(*) FROM spotify_raw GROUP BY album_type
    UNION ALL
    SELECT 'channel', channel, COUNT(*) FROM spotify_raw GROUP BY channel
    UNION ALL
    SELECT 'most_playedon', most_playedon, COUNT(*) FROM spotify_raw GROUP BY most_playedon
)
SELECT
    field_name,
    LOWER(BTRIM(raw_label)) AS normalized_label,
    COUNT(DISTINCT raw_label) AS source_label_variants,
    SUM(source_rows) AS affected_rows
FROM label_values
WHERE raw_label IS NOT NULL
  AND BTRIM(raw_label) <> ''
GROUP BY field_name, LOWER(BTRIM(raw_label))
HAVING COUNT(DISTINCT raw_label) > 1
ORDER BY field_name, affected_rows DESC, normalized_label;

-- 5. Values outside expected bounds and values requiring investigation.
-- Positive loudness and zero tempo/duration are flagged for review, not
-- asserted to be invalid or removed.
SELECT check_name, COUNT(*) AS flagged_rows
FROM (
    SELECT 'danceability outside [0, 1]' AS check_name FROM spotify WHERE danceability < 0 OR danceability > 1
    UNION ALL SELECT 'energy outside [0, 1]' FROM spotify WHERE energy < 0 OR energy > 1
    UNION ALL SELECT 'speechiness outside [0, 1]' FROM spotify WHERE speechiness < 0 OR speechiness > 1
    UNION ALL SELECT 'acousticness outside [0, 1]' FROM spotify WHERE acousticness < 0 OR acousticness > 1
    UNION ALL SELECT 'instrumentalness outside [0, 1]' FROM spotify WHERE instrumentalness < 0 OR instrumentalness > 1
    UNION ALL SELECT 'liveness outside [0, 1]' FROM spotify WHERE liveness < 0 OR liveness > 1
    UNION ALL SELECT 'valence outside [0, 1]' FROM spotify WHERE valence < 0 OR valence > 1
    UNION ALL SELECT 'negative tempo' FROM spotify WHERE tempo < 0
    UNION ALL SELECT 'zero tempo (investigate)' FROM spotify WHERE tempo = 0
    UNION ALL SELECT 'negative duration' FROM spotify WHERE duration_min < 0
    UNION ALL SELECT 'zero duration (investigate)' FROM spotify WHERE duration_min = 0
    UNION ALL SELECT 'negative views' FROM spotify WHERE views < 0
    UNION ALL SELECT 'negative likes' FROM spotify WHERE likes < 0
    UNION ALL SELECT 'negative comments' FROM spotify WHERE comments < 0
    UNION ALL SELECT 'negative stream count' FROM spotify WHERE stream < 0
    UNION ALL SELECT 'positive loudness (investigate)' FROM spotify WHERE loudness > 0
) AS flagged_values
GROUP BY check_name
ORDER BY check_name;

-- Summarize zero-valued engagement metrics. A zero is retained; it may indicate
-- a real zero or missing upstream measurement.
SELECT
    COUNT(*) FILTER (WHERE views = 0) AS zero_view_rows,
    COUNT(*) FILTER (WHERE likes = 0) AS zero_like_rows,
    COUNT(*) FILTER (WHERE comments = 0) AS zero_comment_rows,
    COUNT(*) FILTER (WHERE stream = 0) AS zero_stream_rows
FROM spotify;

-- 6. Preserve and inspect source labels, including "0" in the raw flags.
SELECT 'album_type' AS field_name, album_type AS field_value, COUNT(*) AS row_count
FROM spotify_raw GROUP BY album_type
UNION ALL
SELECT 'licensed', licensed, COUNT(*) FROM spotify_raw GROUP BY licensed
UNION ALL
SELECT 'official_video', official_video, COUNT(*) FROM spotify_raw GROUP BY official_video
UNION ALL
SELECT 'most_playedon', most_playedon, COUNT(*) FROM spotify_raw GROUP BY most_playedon
ORDER BY field_name, row_count DESC;

-- Inspect whitespace without changing any source label.
SELECT
    COUNT(*) FILTER (WHERE channel <> BTRIM(channel)) AS channel_whitespace_rows,
    COUNT(*) FILTER (WHERE title <> BTRIM(title)) AS title_whitespace_rows
FROM spotify_raw;

-- 7. A safe one-row denominator join for the artist-share analysis:
-- the one-row total is CROSS JOINed to one row per artist. These counts should
-- match, demonstrating that this join does not multiply artist rows.
WITH artist_totals AS (
    SELECT artist, SUM(stream) AS artist_streams
    FROM spotify
    GROUP BY artist
),
overall_total AS (
    SELECT SUM(stream) AS all_streams
    FROM spotify
),
joined_result AS (
    SELECT artist_totals.artist, artist_totals.artist_streams, overall_total.all_streams
    FROM artist_totals
    CROSS JOIN overall_total
)
SELECT
    (SELECT COUNT(*) FROM artist_totals) AS artist_rows_before_join,
    COUNT(*) AS artist_rows_after_join,
    (SELECT COUNT(*) FROM artist_totals) = COUNT(*) AS join_preserved_grain
FROM joined_result;
