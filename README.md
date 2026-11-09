# Spotify Dataset SQL Analysis

A PostgreSQL portfolio project exploring track-level audio features and
reported engagement metrics. The analysis demonstrates careful profiling,
non-destructive data-quality checks, aggregation, CTEs, and window functions
without assuming fields or relationships that the dataset does not contain.

## Project objective

The business question is: **How do the records in this Spotify-related dataset
differ in reported streams, views, engagement, audio features, and artist or
album labels?**

This is a descriptive analysis of a static dataset. It does not measure
listeners, revenue, causation, changes over time, or independent performance
on Spotify versus YouTube.

## Dataset and attribution

The downloaded project's README links to the
[Kaggle Spotify Dataset](https://www.kaggle.com/datasets/sanjanchaudhari/spotify-dataset),
uploaded by **Sanjan Chaudhari**. The checked-in CSV's exact version and
redistribution license are not recorded in the downloaded project. Check the
dataset page's current terms before redistributing it. A code license, if added,
does not automatically apply to the dataset.

The original project author and source repository are not identified in the
downloaded files. This work preserves the existing SQL, CSV, and images; it does
not claim authorship of those original materials. No project or dataset license
file was present in the downloaded folder.

**Dataset is not included in this GitHub repository.** Its redistribution
permission has not been verified. Obtain it from the attributed Kaggle page and
check the current terms before use. The `.gitignore` excludes both the original
CSV path and the organized raw-data copy; the local copies remain unchanged.

The original screenshots and banner are also retained locally but excluded
from GitHub because their original authorship and redistribution terms could
not be verified. No copied screenshots or banner are needed to run the SQL.

## Verified dataset profile

The checked-in CSV was inspected directly (these are file-profile measurements,
not PostgreSQL query outputs):

- 20,594 rows and 24 columns.
- Two blank values, both in `energy_liveness`.
- Zero exact duplicate full rows; 92 extra rows among case-insensitive
  artist/track label pairs. Those repeated labels are not assumed to be errors.
- Two rows have zero duration; 19 have zero tempo. These are flagged for review,
  not deleted.
- Each source flag column (`Licensed`, `official_video`) has 469 `0` values.
  Their meaning is undocumented; the analysis view interprets them as unknown.
- No date, genre, region, playlist, listener, or unique track ID column exists.

The source is named `spotify_cleaned_dataset.csv`, but the upstream cleaning
process is not documented. See the [data dictionary](docs/data_dictionary.md)
and [methodology](docs/methodology.md) for field caveats and import decisions.

## Database dialect and schema

**Database:** PostgreSQL. The original project identifies PostgreSQL and uses
PostgreSQL DDL, window functions, `LIMIT`, and the `psql` `\copy` command.

The analysis stores the 24 imported CSV fields in a text-only `spotify_raw`
table, then exposes a typed `spotify` view. The view casts measurements and
counts, leaves blank numeric values as `NULL`, and maps the undocumented `0`
flag sentinel to `NULL` rather than false. The raw source strings remain
available for review. Full field details are in
[`docs/data_dictionary.md`](docs/data_dictionary.md).

## Repository structure

```text
data/raw/spotify_cleaned_dataset.csv   Local dataset copy (not tracked by Git)
dataset/spotify_cleaned_dataset.csv   Original local path (not tracked by Git)
sql/01_schema_and_profiling.sql       Raw schema, typed view, schema/count profile
sql/02_data_quality.sql               Read-only quality and join-grain checks
sql/03_business_analysis.sql          17 business questions, grouped by topic
sql/04_advanced_analysis.sql          Rankings, LAG/LEAD, CTE and join examples
docs/data_dictionary.md               Field types, meanings, and caveats
docs/methodology.md                   Import, cleaning decisions, and limitations
docs/interview_prep.md                Ten project-specific SQL interview Q&As
results/README.md                     Explains why no unexecuted outputs are saved
tests/validate_portfolio.py           Standard-library static/project checks
implementation_report.md              Changes, validation, and remaining actions
project_audit.md                       Phase 1 findings and improvement plan
spotify-querying.sql                  Original SQL retained for reference
images/                               Local reference images (not uploaded)
```

The duplicate CSV under `data/raw/` makes the new layout self-contained. Both
copies were verified to have the same SHA-256 digest during implementation.

## Setup and execution

Requirements: PostgreSQL with `psql`, and Python 3 only for the lightweight
project-integrity check. The SQL analysis itself has no Python dependency.

Run commands from the repository root in a terminal where PostgreSQL is
available. Use a fresh, dedicated database for the initial import:

```powershell
# Download the CSV from the attributed Kaggle page after reviewing its terms.
# Place the same file at both paths (the CSV files are intentionally gitignored):
#   data/raw/spotify_cleaned_dataset.csv
#   dataset/spotify_cleaned_dataset.csv

createdb spotify_analysis
psql -v ON_ERROR_STOP=1 -d spotify_analysis -f sql/01_schema_and_profiling.sql
psql -v ON_ERROR_STOP=1 -d spotify_analysis -c "\copy spotify_raw FROM 'data/raw/spotify_cleaned_dataset.csv' WITH (FORMAT csv, HEADER true)"
psql -v ON_ERROR_STOP=1 -d spotify_analysis -f sql/01_schema_and_profiling.sql
psql -v ON_ERROR_STOP=1 -d spotify_analysis -f sql/02_data_quality.sql
psql -v ON_ERROR_STOP=1 -d spotify_analysis -f sql/03_business_analysis.sql
psql -v ON_ERROR_STOP=1 -d spotify_analysis -f sql/04_advanced_analysis.sql
```

The first schema run creates the raw table and typed view. `\copy` reads the
CSV from the client working directory; run it from the repository root. The
second schema-script run displays the post-import profile. `\copy` appends
rows: do not repeat it in an already-loaded database unless you intentionally
want another copy of every source row. Use a fresh database for a clean rerun.

Run the local static checks from the repository root:

```powershell
python tests/validate_portfolio.py
```

The integrity check requires both local CSV copies and verifies their expected
SHA-256 and row/column counts. It will fail until the matching dataset version
has been obtained and placed at both paths.

## Business questions

The scripts answer 17 supported questions. Each query has a plain-language
question, SQL concepts, and interpretation notes in
[`sql/03_business_analysis.sql`](sql/03_business_analysis.sql).

| Area | Questions |
|---|---|
| Track performance | Highest reported stream totals; most-viewed official-video records; like/view ratios; engagement by album type |
| Artist performance | High-total-stream artists; top viewed records per artist; artist share of reported streams |
| Album performance | Highest-stream artist/album labels; audio-feature averages by album type |
| Popularity patterns | Stream bands; cumulative catalog stream share; `most_playedon` category summary; licensing/video flag groups; audio features by stream band |
| Duration | Duration bands and long records to review |

Genre, regional, release-date, playlist, and time-trend questions are excluded
because those fields are absent. `most_playedon` is a single category per row,
not separate platform metrics.

## SQL concepts demonstrated

- Filtering, grouping, sorting, `CASE WHEN`, and aggregate functions.
- Null-aware ratios using `NULLIF`, plus explicit unknown-flag handling.
- CTEs and a subquery-style aggregate workflow.
- A cardinality-safe `CROSS JOIN` to attach a one-row overall total to
  artist-level aggregates, with a row-count check.
- `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `PARTITION BY`, `LAG`, and `LEAD`.
- A cumulative window calculation for catalog stream concentration.

No moving average is used: without a valid date field, a moving average would
not represent a time series.

## Findings and validation status

Verified observations from inspecting the CSV are listed above. They are not
presented as SQL query results. No result exports are saved: a local PostgreSQL
18 service is running, but connecting requires a password that was not
available in the implementation environment. Static project checks validate
CSV preservation, file/link structure, and analysis coverage; they do not
replace running these scripts against PostgreSQL.

The original [`spotify-querying.sql`](spotify-querying.sql) is preserved as a
reference, not the recommended workflow: it drops a table and deletes
zero-duration rows. The new scripts do not modify or delete raw records.
Screenshots in `images/` are retained from the downloaded project; their
execution environment and performance measurements were not independently
verified.

## Limitations

- No stable track or album ID; label-based grouping can combine distinct
  records or split one entity across inconsistent labels.
- No date or documented observation time; no trend, release, or moving-average
  analysis is supported.
- No genre, region, playlist, listener, or revenue fields.
- No independent platform stream metrics; no cross-platform performance
  conclusion is supported.
- `0` flag sentinels, zero duration/tempo, and zero engagement values require
  source-owner context before a final cleaning decision.
- Descriptive comparisons do not establish causal relationships.

## Portfolio descriptions

**Resume:** Built a PostgreSQL analysis workflow for a 20.6K-row Spotify-related
dataset, preserving raw CSV values while creating a typed view, read-only data
quality checks, 17 documented business queries, and window-function analyses.
Documented schema limitations and reproducibility; PostgreSQL execution remains
to be completed in an available database environment.

**LinkedIn:** Developed a portfolio SQL project profiling a 20,594-row
Spotify-related dataset. Created a non-destructive PostgreSQL workflow with a
raw text table, typed view, reproducible quality checks, 17 business questions,
and advanced ranking/window analyses. Documented missing fields and avoided
unsupported platform or time-trend claims. SQL runtime validation is pending a
PostgreSQL environment.
