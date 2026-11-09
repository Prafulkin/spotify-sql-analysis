# SQL Interview Prep

These answers refer to the schema and analysis in this repository. No numerical
business result is asserted unless it is produced by running the SQL.

## 1. What is the grain of the dataset?

One supplied CSV row. The schema has no stable track ID, so a row cannot be
assumed to be one unique Spotify recording. Aggregations group by explicit
labels such as artist, track, and album and are described as label-based totals.

## 2. Why import the CSV into a text-only raw table first?

It preserves the original field strings, blanks, and flag sentinel values.
The typed view can then cast values for analysis without modifying or losing
the imported source representation.

## 3. How are unknown flag values handled?

`TRUE` and `FALSE` are converted to booleans. The source value `0` becomes
`NULL` in the analysis view because its meaning is undocumented. It remains
visible in `spotify_raw`, and queries can report it as `Unknown` rather than
misclassifying it as false.

## 4. What is the difference between `RANK`, `DENSE_RANK`, and `ROW_NUMBER`?

`RANK` assigns equal ranks to ties and leaves gaps afterward. `DENSE_RANK`
assigns equal ranks but does not leave gaps. `ROW_NUMBER` gives every row a
different position; deterministic tie-break columns are used to make that
ordering reproducible. The advanced query shows all three per artist.

## 5. What do `LAG` and `LEAD` mean in this analysis?

They return the preceding or following row within an artist's explicitly
sorted view ranking. Since the dataset has no date, those functions compare
rank neighbors, not earlier and later releases.

## 6. Why use `NULLIF` in an engagement ratio?

`NULLIF(views, 0)` returns `NULL` when views is zero. Division then returns
`NULL` instead of raising a divide-by-zero error or inventing a ratio. `AVG`
ignores these null ratios; a count of valid ratios can show coverage.

## 7. Why not remove repeated artist/track rows?

The data has no unique track key, and repeated labels may refer to different
album or video records. Exact duplicate rows are checked separately. Neither
case is silently removed from the preserved source.

## 8. How is join cardinality controlled?

The artist-share analysis aggregates to one row per artist and cross joins a
single-row total. A data-quality check compares row counts before and after
the join. No unsupported artist/album dimension tables are invented.

## 9. Why are there no release trends or moving averages?

The CSV has no valid observation or release date. Ordering by popularity or
duration does not create a time axis, so a moving average would be misleading.

## 10. What would you verify before presenting the findings?

Load the CSV into a fresh PostgreSQL database, run the schema/import steps,
then execute the profiling, data-quality, business, and advanced scripts in
order. Confirm row counts, inspect flagged data, verify joins preserve grain,
and report only results reproduced by those queries. The SQL was not run
against PostgreSQL in this environment.
