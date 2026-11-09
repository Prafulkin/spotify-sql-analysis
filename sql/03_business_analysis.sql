-- Business analysis questions supported by the available columns.
-- Grain reminder: a row is a supplied track/video-style record, not a
-- guaranteed unique Spotify recording. Aggregations below say which labels
-- they group by; do not interpret row counts as deduplicated track counts.

/* -------------------------------------------------------------------------
   1. Track and song-record performance
   ------------------------------------------------------------------------- */

-- Q1. Which artist/track/album records have the largest reported stream totals?
-- Concepts: GROUP BY, SUM, HAVING, ORDER BY, LIMIT.
-- Interpretation: these are sums of source rows for each label combination;
-- the dataset has no stable track ID for more precise deduplication.
SELECT
    artist,
    track,
    album,
    COUNT(*) AS source_rows,
    SUM(stream) AS reported_streams
FROM spotify
GROUP BY artist, track, album
HAVING COUNT(stream) > 0
ORDER BY reported_streams DESC, artist, track, album
LIMIT 20;

-- Q2. Which official-video records have the highest view counts?
-- Concepts: WHERE, ORDER BY, NULL handling.
-- Interpretation: this ranks observed rows marked official_video = TRUE;
-- rows whose source flag was "0" are unknown in the typed view and excluded.
SELECT artist, track, album, title, views, likes
FROM spotify
WHERE official_video IS TRUE
  AND views IS NOT NULL
ORDER BY views DESC, artist, track
LIMIT 20;

-- Q3. Among records with views, which have the highest like-to-view percentage?
-- Concepts: NULLIF, calculated columns, filtering, sorting.
-- Interpretation: this is a descriptive ratio of supplied counts, not a causal
-- conversion rate or a measure of unique listeners.
SELECT
    artist,
    track,
    title,
    views,
    likes,
    ROUND(100.0 * likes::NUMERIC / NULLIF(views, 0), 2) AS likes_per_100_views_pct
FROM spotify
WHERE views > 0
  AND likes IS NOT NULL
ORDER BY likes_per_100_views_pct DESC, views DESC, artist, track
LIMIT 20;

-- Q4. How do average reported engagement totals differ by album type?
-- Concepts: GROUP BY and multiple aggregates.
-- Interpretation: averages describe rows in this dataset, not a typical
-- listener's behavior. Unknown album types remain visible as their own group.
SELECT
    COALESCE(NULLIF(BTRIM(album_type), ''), '(unknown)') AS album_type,
    COUNT(*) AS source_rows,
    ROUND(AVG(views::NUMERIC), 0) AS avg_views,
    ROUND(AVG(likes::NUMERIC), 0) AS avg_likes,
    ROUND(AVG(comments::NUMERIC), 0) AS avg_comments
FROM spotify
GROUP BY COALESCE(NULLIF(BTRIM(album_type), ''), '(unknown)')
ORDER BY avg_views DESC NULLS LAST;

-- Q5. What is the average comments-per-view ratio by album type?
-- Concepts: NULLIF, AVG, COUNT.
-- Interpretation: zero-view rows produce NULL ratios and are not used in AVG;
-- groups with no valid denominator return NULL rather than a fabricated zero.
SELECT
    COALESCE(NULLIF(BTRIM(album_type), ''), '(unknown)') AS album_type,
    COUNT(*) AS source_rows,
    COUNT(comments::NUMERIC / NULLIF(views, 0)) AS rows_with_ratio,
    ROUND(
        AVG(comments::NUMERIC / NULLIF(views, 0)) * 1000,
        3
    ) AS avg_comments_per_1000_views
FROM spotify
GROUP BY COALESCE(NULLIF(BTRIM(album_type), ''), '(unknown)')
ORDER BY avg_comments_per_1000_views DESC NULLS LAST;

/* -------------------------------------------------------------------------
   2. Artist performance
   ------------------------------------------------------------------------- */

-- Q6. Which artists have the largest total reported stream counts?
-- Concepts: GROUP BY, SUM, HAVING, ORDER BY.
-- Interpretation: the five-row minimum reduces very small groups; it is an
-- analysis choice, not a claim that those artists are more representative.
SELECT
    artist,
    COUNT(*) AS source_rows,
    SUM(stream) AS reported_streams,
    ROUND(AVG(stream::NUMERIC), 0) AS avg_streams_per_source_row
FROM spotify
GROUP BY artist
HAVING COUNT(*) >= 5
ORDER BY reported_streams DESC NULLS LAST, artist
LIMIT 25;

-- Q7. Which artist/track/album records lead each artist by total reported views?
-- Concepts: CTE, aggregation, RANK and PARTITION BY.
-- Interpretation: RANK preserves ties for highest views; more than one row may
-- rank first for an artist. This is a label-based rollup, not an ID-level result.
WITH artist_track_views AS (
    SELECT artist, track, album, SUM(views) AS total_views
    FROM spotify
    GROUP BY artist, track, album
),
ranked_tracks AS (
    SELECT
        artist,
        track,
        album,
        total_views,
        RANK() OVER (
            PARTITION BY artist
            ORDER BY total_views DESC NULLS LAST
        ) AS view_rank
    FROM artist_track_views
)
SELECT artist, track, album, total_views, view_rank
FROM ranked_tracks
WHERE view_rank <= 3
ORDER BY artist, view_rank, track, album;

-- Q8. What share of all reported streams is attributed to each artist?
-- Concepts: two CTEs, aggregate JOIN, CROSS JOIN, numeric ratios.
-- Interpretation: each artist aggregate is joined to one overall-total row.
-- The companion cardinality check in sql/02_data_quality.sql verifies that
-- this one-row denominator does not multiply the artist rows.
WITH artist_totals AS (
    SELECT artist, SUM(stream) AS artist_streams
    FROM spotify
    GROUP BY artist
),
overall_total AS (
    SELECT SUM(stream) AS all_streams
    FROM spotify
)
SELECT
    artist_totals.artist,
    artist_totals.artist_streams,
    ROUND(
        100.0 * artist_totals.artist_streams / NULLIF(overall_total.all_streams, 0),
        3
    ) AS share_of_reported_streams_pct
FROM artist_totals
CROSS JOIN overall_total
ORDER BY artist_totals.artist_streams DESC NULLS LAST
LIMIT 25;

/* -------------------------------------------------------------------------
   3. Album performance
   ------------------------------------------------------------------------- */

-- Q9. Which artist/album labels have the largest combined reported streams?
-- Concepts: aggregation, HAVING, ranking by aggregate.
-- Interpretation: labels may not uniquely identify an album; totals are the
-- sum of the records bearing each artist and album label.
SELECT
    artist,
    album,
    COUNT(*) AS source_rows,
    SUM(stream) AS reported_streams,
    ROUND(AVG(duration_min::NUMERIC), 2) AS avg_duration_min
FROM spotify
GROUP BY artist, album
HAVING COUNT(stream) > 0
ORDER BY reported_streams DESC NULLS LAST, artist, album
LIMIT 25;

-- Q10. How do catalog audio features vary across album types?
-- Concepts: GROUP BY, AVG, NULL-aware aggregates.
-- Interpretation: the values are descriptive averages over available rows;
-- they do not imply that album type causes an audio-feature difference.
SELECT
    album_type,
    COUNT(*) AS source_rows,
    COUNT(danceability) AS rows_with_danceability,
    ROUND(AVG(danceability::NUMERIC), 3) AS avg_danceability,
    ROUND(AVG(energy::NUMERIC), 3) AS avg_energy,
    ROUND(AVG(valence::NUMERIC), 3) AS avg_valence
FROM spotify
GROUP BY album_type
ORDER BY source_rows DESC, album_type;

/* -------------------------------------------------------------------------
   4. Popularity and source-label patterns
   ------------------------------------------------------------------------- */

-- Q11. How many records fall into transparent stream-count bands?
-- Concepts: CASE WHEN, conditional aggregation, GROUP BY.
-- Interpretation: these cutoffs are convenient descriptive bands, not an
-- official Spotify popularity classification.
WITH classified_streams AS (
    SELECT
        CASE
            WHEN stream IS NULL THEN 'Unknown'
            WHEN stream = 0 THEN 'Zero'
            WHEN stream < 100000000 THEN 'Under 100M'
            WHEN stream < 500000000 THEN '100M to <500M'
            WHEN stream < 1000000000 THEN '500M to <1B'
            ELSE '1B or more'
        END AS stream_band,
        stream,
        views
    FROM spotify
)
SELECT
    stream_band,
    COUNT(*) AS source_rows,
    SUM(stream) AS reported_streams,
    ROUND(AVG(views::NUMERIC), 0) AS avg_views
FROM classified_streams
GROUP BY stream_band
ORDER BY
    CASE stream_band
        WHEN 'Unknown' THEN 0
        WHEN 'Zero' THEN 1
        WHEN 'Under 100M' THEN 2
        WHEN '100M to <500M' THEN 3
        WHEN '500M to <1B' THEN 4
        ELSE 5
    END;

-- Q12. How concentrated are reported streams among artist/track/album labels?
-- Concepts: CTE, SUM window frames, PARTITION-free window total.
-- Interpretation: cumulative percentage describes concentration in this
-- supplied catalog extract; it is not a time trend or listener-share metric.
WITH track_totals AS (
    SELECT artist, track, album, SUM(stream) AS track_streams
    FROM spotify
    GROUP BY artist, track, album
),
cumulative_streams AS (
    SELECT
        artist,
        track,
        album,
        track_streams,
        SUM(track_streams) OVER (
            ORDER BY track_streams DESC NULLS LAST, artist, track, album
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_streams,
        SUM(track_streams) OVER () AS all_streams
    FROM track_totals
)
SELECT
    artist,
    track,
    album,
    track_streams,
    ROUND(
        100.0 * cumulative_streams / NULLIF(all_streams, 0),
        2
    ) AS cumulative_stream_share_pct
FROM cumulative_streams
ORDER BY track_streams DESC NULLS LAST, artist, track, album
LIMIT 100;

-- Q13. How do the source's "most_playedon" categories break down?
-- Concepts: GROUP BY and conditional aggregates.
-- Interpretation: this field is one categorical label per source row; it does
-- not contain independent platform stream measurements for a head-to-head test.
SELECT
    most_playedon,
    COUNT(*) AS source_rows,
    SUM(stream) AS sum_of_reported_stream_values,
    COUNT(stream) AS rows_with_stream_value
FROM spotify
GROUP BY most_playedon
ORDER BY source_rows DESC, most_playedon;

-- Q14. How do known licensing/video flags relate to row counts and engagement?
-- Concepts: CASE, COUNT, AVG, NULL handling.
-- Interpretation: NULL is shown as unknown. These are associations in the
-- supplied records, not evidence that a flag causes higher engagement.
SELECT
    CASE WHEN licensed IS TRUE THEN 'Licensed'
         WHEN licensed IS FALSE THEN 'Not licensed'
         ELSE 'Unknown' END AS license_status,
    CASE WHEN official_video IS TRUE THEN 'Official video'
         WHEN official_video IS FALSE THEN 'Not official'
         ELSE 'Unknown' END AS video_status,
    COUNT(*) AS source_rows,
    ROUND(AVG(views::NUMERIC), 0) AS avg_views,
    ROUND(AVG(likes::NUMERIC), 0) AS avg_likes
FROM spotify
GROUP BY 1, 2
ORDER BY source_rows DESC, license_status, video_status;

-- Q15. What is the average audio profile within reported-stream bands?
-- Concepts: CASE WHEN and grouped aggregates.
-- Interpretation: this compares descriptive feature averages across bands;
-- it does not establish that audio features drive streaming outcomes.
SELECT
    CASE
        WHEN stream IS NULL THEN 'Unknown'
        WHEN stream = 0 THEN 'Zero'
        WHEN stream < 100000000 THEN 'Under 100M'
        WHEN stream < 500000000 THEN '100M to <500M'
        WHEN stream < 1000000000 THEN '500M to <1B'
        ELSE '1B or more'
    END AS stream_band,
    COUNT(*) AS source_rows,
    ROUND(AVG(danceability::NUMERIC), 3) AS avg_danceability,
    ROUND(AVG(energy::NUMERIC), 3) AS avg_energy,
    ROUND(AVG(acousticness::NUMERIC), 3) AS avg_acousticness,
    ROUND(AVG(instrumentalness::NUMERIC), 3) AS avg_instrumentalness
FROM spotify
GROUP BY 1
ORDER BY source_rows DESC, stream_band;

/* -------------------------------------------------------------------------
   5. Duration analysis
   ------------------------------------------------------------------------- */

-- Q16. How do duration bands compare on average streams and audio features?
-- Concepts: CASE WHEN, GROUP BY, AVG, NULL handling.
-- Interpretation: the <3, 3-to-<5, and 5+ minute bands are analyst-selected
-- descriptions, not standard industry categories. Zero durations are retained
-- and separately flagged by the data-quality script.
SELECT
    CASE
        WHEN duration_min IS NULL THEN 'Unknown'
        WHEN duration_min < 3 THEN 'Under 3 min'
        WHEN duration_min < 5 THEN '3 to under 5 min'
        ELSE '5 min or more'
    END AS duration_band,
    COUNT(*) AS source_rows,
    ROUND(AVG(stream::NUMERIC), 0) AS avg_streams,
    ROUND(AVG(views::NUMERIC), 0) AS avg_views,
    ROUND(AVG(energy::NUMERIC), 3) AS avg_energy
FROM spotify
GROUP BY 1
ORDER BY source_rows DESC, duration_band;

-- Q17. Which unusually long records should be reviewed before summarizing
-- duration? This is a review list, not an automatic outlier deletion rule.
-- Concepts: WHERE, ORDER BY, LIMIT.
SELECT artist, track, album, duration_min, stream, views
FROM spotify
WHERE duration_min IS NOT NULL
ORDER BY duration_min DESC, artist, track
LIMIT 20;

/* -------------------------------------------------------------------------
   Schema coverage
   ------------------------------------------------------------------------- */

-- Genre, region, playlist, and release-date analyses are intentionally absent:
-- no corresponding fields or relationships exist in the supplied CSV.
