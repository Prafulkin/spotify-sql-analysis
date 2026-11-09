# Data Dictionary

## Dataset grain and import

The supplied CSV contains **20,594 rows** and **24 columns**. Each row is one
record in the supplied, already-named “cleaned” dataset. It is not safe to
assume one row equals one unique Spotify recording: there is no track ID, and
some artist/track labels repeat. The project keeps the imported values in the
text-only `spotify_raw` table and provides the typed `spotify` view for analysis.

The field meanings below follow the column names and observed values. Fields
without a provided source definition are not assigned a stronger meaning than
the data supports.

| CSV field | Analysis-view type | Description and caveats |
|---|---|---|
| `Artist` | `TEXT` | Artist label. Not a normalized artist identifier. |
| `Track` | `TEXT` | Track label. Not a unique track ID. |
| `Album` | `TEXT` | Album label. Not a unique album ID. |
| `Album_type` | `TEXT` | Observed labels: `album`, `single`, `compilation`. |
| `Danceability` | `DOUBLE PRECISION` | Audio-feature value observed between 0 and 1. Source-specific definition is not included. |
| `Energy` | `DOUBLE PRECISION` | Audio-feature value observed between 0 and 1. |
| `Loudness` | `DOUBLE PRECISION` | Numeric loudness-like value; observed range is -46.251 to 0.92. Positive values are flagged for review, not automatically rejected. |
| `Speechiness` | `DOUBLE PRECISION` | Audio-feature value observed between 0 and 1. |
| `Acousticness` | `DOUBLE PRECISION` | Audio-feature value observed between 0 and 1. |
| `Instrumentalness` | `DOUBLE PRECISION` | Audio-feature value observed between 0 and 1. |
| `Liveness` | `DOUBLE PRECISION` | Audio-feature value observed between 0 and 1. |
| `Valence` | `DOUBLE PRECISION` | Audio-feature value observed between 0 and 1. |
| `Tempo` | `DOUBLE PRECISION` | Numeric tempo-like value; 19 rows contain zero, which is flagged for review. |
| `Duration_min` | `DOUBLE PRECISION` | Duration in minutes according to the column label; two rows are zero. |
| `Title` | `TEXT` | Video/title-like label. It is not a unique track identifier. |
| `Channel` | `TEXT` | Channel-like label. Some source values contain surrounding whitespace. |
| `Views` | `BIGINT` | Non-negative integer-valued view count in the CSV; measurement source and snapshot time are unspecified. |
| `Likes` | `BIGINT` | Non-negative integer-valued like count; measurement source and snapshot time are unspecified. |
| `Comments` | `BIGINT` | Non-negative integer-valued comment count; measurement source and snapshot time are unspecified. |
| `Licensed` | `BOOLEAN` or `NULL` | `TRUE`/`FALSE` are cast to booleans. Source value `0` is treated as unknown (`NULL`) because its meaning is undocumented. |
| `official_video` | `BOOLEAN` or `NULL` | `TRUE`/`FALSE` are cast to booleans. Source value `0` is treated as unknown (`NULL`). |
| `Stream` | `BIGINT` | Non-negative integer-valued stream count in the CSV; source platform and snapshot time are not specified per row. |
| `energy_liveness` | `DOUBLE PRECISION` or `NULL` | Numeric field with two blank values. Its derivation is not documented, so it is not recomputed. |
| `most_playedon` | `TEXT` | Observed labels: `Spotify` and `Youtube`. This is a single category per row, not a pair of platform-specific metrics. |

## Missing values and data types

The raw table stores every CSV field as `TEXT` so blank cells and original flag
values remain inspectable. The analysis view casts numeric values to
`DOUBLE PRECISION` or `BIGINT`, and flag values to `BOOLEAN`. Empty numeric
strings become `NULL`; a flag value of `0` becomes `NULL` rather than `FALSE`.
Unexpected nonnumeric strings fail the cast visibly instead of being silently
discarded.

No date, genre, region, playlist, listener, revenue, or stable ID column exists.
The `stream` and engagement values should not be attributed to an unlisted
platform or treated as a time series.
