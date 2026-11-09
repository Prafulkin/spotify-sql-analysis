# Project Audit

## Scope and method

This audit covers the files present in the downloaded project, the existing SQL
and README, the CSV contents, and the available local SQL tools. No source data
or existing project file was changed during the audit. CSV statistics were
calculated directly from `dataset/spotify_cleaned_dataset.csv` with Python's
standard-library CSV reader.

## Repository inventory

| Path | Contents |
|---|---|
| `README.md` | PostgreSQL project overview, schema, query descriptions, optimization screenshots, and setup instructions |
| `spotify-querying.sql` | Table DDL, profiling statements, a destructive duration cleanup, and 13 analysis queries |
| `dataset/spotify_cleaned_dataset.csv` | The supplied dataset, approximately 5.18 MB |
| `images/` | One Spotify banner and five query-plan screenshots |

No dependency manifest, test or validation scripts, data dictionary, methodology
document, separate raw/processed data folders, or license file is present. The
downloaded directory is not a Git repository, so the original project author
cannot be established from local Git metadata.

## Dataset and provenance

The README links to the Kaggle dataset page
[Spotify Dataset](https://www.kaggle.com/datasets/sanjanchaudhari/spotify-dataset)
and identifies the uploader as Sanjan Chaudhari in the URL. This is the only
dataset attribution found locally; the checked-in CSV's exact version and
license/redistribution terms are not documented. The project README also does
not identify the original project author or provide a source-repository link.
Those details should be verified before strengthening attribution claims.

The CSV has **20,594 data rows** and **24 columns**. This differs slightly from
the README's approximate “~20,590”/“~20,590 tracks” statements. There is no
track ID or date field. The file is already named “cleaned”; its upstream
preparation process is not described, so it cannot be treated as raw source
data without qualification.

### Observed schema

| Column(s) | Observed values / likely type | Notes |
|---|---|---|
| `Artist`, `Track`, `Album`, `Album_type`, `Title`, `Channel`, `most_playedon` | Text | No blank values observed; `Channel` has 33 values with surrounding whitespace and `Title` has 2. |
| `Danceability`, `Energy`, `Speechiness`, `Acousticness`, `Instrumentalness`, `Liveness`, `Valence` | Numeric decimal | Observed range is 0–1 for each feature. |
| `Loudness` | Numeric decimal | Observed range -46.251 to 0.92. |
| `Tempo`, `Duration_min` | Numeric decimal | Tempo ranges 0–243.372; duration ranges 0–77.9343 minutes. |
| `Views`, `Likes`, `Comments`, `Stream` | Non-negative integer-valued numbers | Maximum observed views: 8,079,649,362; stream: 3,386,520,288. |
| `Licensed`, `official_video` | Text-like flags | Each has `TRUE`, `FALSE`, and `0`; the `0` value appears in 469 rows per field and needs explicit import/cleaning treatment. |
| `energy_liveness` | Numeric decimal or missing | Two blank values; likely derived, but its formula and upstream handling are undocumented. |

The existing PostgreSQL DDL maps the 24 fields positionally and is broadly
consistent with the CSV. Date-based analysis is not supported by this schema.
There are no genre, playlist, or independent per-platform engagement columns;
`most_playedon` is a single category, not a platform-by-platform observation.

## Data-quality findings

- **Missing values:** 2 blank `energy_liveness` cells; no other blank CSV fields.
- **Exact duplicate rows:** 0.
- **Repeated artist/track pairs:** 92 extra rows beyond one row per
  case-insensitive `(Artist, Track)` pair. These may represent different
  recordings, albums, or other source-level variants; they are not safe to
  delete as duplicates without a documented business key.
- **Zero duration:** 2 rows. The existing SQL deletes these rows from the
  working table; the source CSV itself remains unchanged. The reason for
  treating zero duration as invalid is plausible but should be reported and
  made repeatable rather than silently applied.
- **Audio feature bounds:** all seven 0–1 audio features remain within their
  expected bounds in the inspected CSV.
- **Potentially suspicious values:** 19 rows have zero tempo; 470 rows have
  zero views, 557 zero likes, 1,065 zero comments, and 576 zero streams. Zeros
  may be genuine or placeholders; they should be flagged and investigated,
  not automatically removed.
- **Text consistency:** no blank artist, track, album, album-type, or platform
  labels. Besides the flag sentinel `0`, observed album types are `album`,
  `single`, and `compilation`; platform labels are `Spotify` and `Youtube`.
- **Other limitations:** no stable track identifier, dates, genre, playlist
  membership, or independent Spotify/YouTube metric columns. Track-name-only
  grouping can merge different artists or recordings.

## SQL dialect and execution status

The project uses **PostgreSQL**: its README names PostgreSQL and the SQL uses
PostgreSQL-compatible DDL, `LIMIT`, window functions, CTEs, and PostgreSQL
`\copy` instructions. At initial audit time, `psql` and `postgres` were not on
`PATH`; during implementation a PostgreSQL 18 Windows service and its bundled
`psql.exe` were located. A non-interactive connection attempt failed because
the server requires a password (`fe_sendauth: no password supplied`). DuckDB
and SQLite executables were not available, and no SQL parser or PostgreSQL
driver was installed. Therefore the original and new SQL could not be executed
against the database in this environment; results and execution plans shown in
screenshots/README are not independently verified here.

Static inspection found a likely script-stopping syntax error: the final
statement of the per-artist ranking query (`WHERE rank <= 3`) is not terminated
with a semicolon before the next `SELECT`. The destructive `DROP TABLE IF
EXISTS` and `DELETE` also make reruns capable of discarding a pre-existing
table or altering loaded working data. The README's `\copy` command is a
psql-only client command and requires the path to be resolved from the client
working directory.

The README lists five advanced questions, but only three advanced queries are
implemented in the SQL file; the energy/liveness ratio and cumulative-likes
questions are described as future extensions. The platform comparison groups
by track name, assumes `most_playedon` identifies comparable platform stream
observations, and excludes tracks with no YouTube value. Its business meaning
is therefore not established by the available schema. The reported indexing
speedup is accompanied by screenshots, but cannot be independently reproduced
without the original database, query, index setup, and execution environment.

## Improvement plan

1. Preserve the supplied CSV and existing screenshots; record their source and
   license status without inferring dataset rights from a code license.
2. Organize PostgreSQL scripts into schema/profiling, non-destructive data
   quality checks, business analysis, and advanced analysis. Avoid table drops
   and source-row deletion in routine analysis.
3. Add reproducible checks for counts, missing values, duplicates, expected
   feature ranges, zero/suspicious values, and categorical labels; report
   exceptions without silently cleaning them.
4. Build at least 15 clearly explained business questions from fields the
   dataset actually contains. Use window functions only for useful ranking or
   within-track comparisons; exclude date, genre, playlist, and unsupported
   platform comparisons.
5. Add a data dictionary and methodology notes describing field meaning,
   import assumptions, cleaning decisions, and limitations.
6. Rewrite setup instructions and README claims to match the actual dataset,
   scripts, and verified results. Distinguish static checks from database
   execution until PostgreSQL validation is available.
7. Validate syntax and results against PostgreSQL if a server becomes
   available; otherwise provide clearly labeled static validation and
   reproducible commands.
