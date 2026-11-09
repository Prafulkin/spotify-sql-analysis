# Implementation Report

## Summary

Implemented the approved portfolio update after completing
[`project_audit.md`](project_audit.md). The original dataset, original SQL file,
and screenshots remain in the local project. The CSV was copied byte-for-byte into the new
`data/raw/` structure; the original `dataset/` path remains present.
The SHA-256 for both CSV copies is
`81fcba40535050410ba48359db8c21b66d6b8160e3ad46c676461c4d251ad7a4`.

## Files changed or added

- Updated `README.md` with project scope, dataset attribution and limitations,
  PostgreSQL setup, execution order, questions, SQL concepts, profile facts,
  and resume/LinkedIn descriptions.
- Added four SQL scripts under `sql/`:
  - `01_schema_and_profiling.sql` defines a text-only raw table, a typed view,
    and table/column/count/category profiles.
  - `02_data_quality.sql` checks distinct and missing values, exact/repeated
    labels, value bounds, suspicious values, and join cardinality.
  - `03_business_analysis.sql` contains 17 commented business questions.
  - `04_advanced_analysis.sql` demonstrates CTEs, `ROW_NUMBER`, `RANK`,
    `DENSE_RANK`, `PARTITION BY`, `LAG`, and `LEAD`.
- Added `docs/data_dictionary.md`, `docs/methodology.md`, and
  `docs/interview_prep.md`.
- Added `results/README.md`; no unexecuted query results were saved.
- Added `tests/validate_portfolio.py`, a Python-standard-library static
  integrity check. It is not a SQL parser or database test.
- Added `data/raw/spotify_cleaned_dataset.csv`, preserving the original CSV
  unchanged at its original path as well.
- Retained `spotify-querying.sql`, `dataset/spotify_cleaned_dataset.csv`, and
  all existing `images/` files locally. `.gitignore` excludes both CSV copies
  because dataset redistribution permission is unverified, and excludes the
  original images because their redistribution terms are unverified.
- Updated `project_audit.md` with the PostgreSQL service discovery and
  authentication limitation found during implementation.

## Executed checks

Command run from the repository root:

```powershell
python tests/validate_portfolio.py
```

Result: **PASS**. The script verified the audited CSV row/column counts and
SHA-256, byte identity of the raw-data copy, agreement between CSV headers and
the raw-table column order, presence of the four SQL scripts and 17 business
questions, non-destructive SQL structure, balanced parentheses/statement
terminators, required analytical techniques, absence of unsupported field
references, required documentation files, and README/documentation relative
links. This is a static project check; it does not parse or execute SQL in
PostgreSQL.

## PostgreSQL execution status

A PostgreSQL 18 Windows service is running locally and its `psql.exe` is
installed outside `PATH`; `pg_isready` confirmed `localhost:5432` accepts
connections. A non-interactive connection attempt to the local
`postgres` database failed with `fe_sendauth: no password supplied`. No
database credentials were available to this task, and no authentication
settings or user data were changed. Consequently, the new SQL has **not** been
executed or syntax-validated by PostgreSQL in this environment.

After an authorized local PostgreSQL connection is available, follow the
commands in `README.md` to create a fresh database, import the CSV, and execute
all four SQL scripts. Save query outputs only after that execution and review.

## Unresolved manual actions

1. Authenticate to the installed PostgreSQL service, then execute all scripts
   using the README instructions and review runtime output.
2. Verify the original portfolio author's identity/source repository and add
   attribution if it can be established; it is not identified in the downloaded
   files.
3. Check current Kaggle dataset license/redistribution terms before publishing
   the CSV or images. The project does not infer a dataset license.
