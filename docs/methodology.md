# Methodology

## Source and attribution

The downloaded README links the dataset to the Kaggle page
[Spotify Dataset by Sanjan Chaudhari](https://www.kaggle.com/datasets/sanjanchaudhari/spotify-dataset).
The CSV’s exact release/version and dataset license are not recorded in the
downloaded project. Verify Kaggle's current dataset terms before redistribution.
The original project author's identity and source repository are not provided
in the downloaded files; this portfolio enhancement does not claim authorship
of the original SQL, CSV, or screenshots.

## Preservation and preparation

- The supplied CSV was not edited. A byte-for-byte copy is provided at
  `data/raw/spotify_cleaned_dataset.csv`; the original
  `dataset/spotify_cleaned_dataset.csv` path remains in place.
- The raw import table, `spotify_raw`, uses 24 `TEXT` columns. This preserves
  source values, including blank cells and the `0` sentinels in the two flag
  fields.
- The `spotify` view casts the raw text to analysis types. Blank numeric values
  become SQL `NULL`. For `licensed` and `official_video`, `TRUE` and `FALSE`
  become booleans, while `0` is interpreted as unknown and becomes `NULL`.
  This is an explicit analysis-layer decision; raw values remain available.
- No source rows are deleted, deduplicated, or overwritten. Exact duplicates,
  repeated labels, zero duration, zero tempo, zero engagement values, and
  positive loudness values are surfaced as quality findings for review.
- No undocumented formula is applied to `energy_liveness`.

## Analysis choices

- The working grain is one supplied CSV row. Artist/track/album aggregations
  sum or average rows with those labels; labels are not treated as unique IDs.
- Query filters and groupings are visible in each query. Unknown flags remain
  identifiable as `Unknown` rather than being counted as false.
- Ratios use `NULLIF(denominator, 0)` to avoid divide-by-zero errors. SQL
  aggregates such as `AVG` naturally ignore `NULL`; query outputs include
  counts where that distinction helps interpret coverage.
- Stream-count and duration bands are analyst-selected descriptive cutoffs,
  not official popularity or industry classifications.
- Rankings use explicit ordering. `RANK` and `DENSE_RANK` preserve ties;
  `ROW_NUMBER` uses tie-break labels to produce deterministic row order.
- `LAG` and `LEAD` compare adjacent records in a ranked list, not in time.
- The artist-share query joins each artist aggregate to one overall-total row.
  A separate cardinality check verifies the join preserves one row per artist.
- No moving average, release trend, genre or regional analysis is included:
  the data has no valid date, genre or region field. No Spotify-versus-YouTube
  performance comparison is made because the dataset does not provide
  independent platform-specific stream metrics.

## Limitations

This is a descriptive analysis of a static extract with undocumented metric
collection times and definitions. The dataset has no stable track identifier,
release date, genre, region, playlist, or listener-level data. Repeated
artist/track labels cannot be assumed to be duplicate records. The project
cannot support causal claims, trend claims, unique-listener conclusions, or
reliable platform-to-platform performance comparisons.

## Validation status

CSV shape, field values, selected quality counts, and the raw-copy hash were
checked locally. PostgreSQL client/server tools were not available during this
implementation, so the SQL scripts have not been executed against PostgreSQL.
Static project checks are documented in
[`implementation_report.md`](../implementation_report.md); run the SQL in
PostgreSQL using the commands in the repository README to validate runtime
behavior and produce any query result exports.
