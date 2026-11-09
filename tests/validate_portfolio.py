"""Standard-library integrity and static-structure checks for this portfolio."""

import csv
import hashlib
import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_SHA256 = "81fcba40535050410ba48359db8c21b66d6b8160e3ad46c676461c4d251ad7a4"
EXPECTED_ROWS = 20594
EXPECTED_COLUMNS = 24


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def strip_sql_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.DOTALL)
    return re.sub(r"--.*$", "", sql, flags=re.MULTILINE)


def static_sql_body(sql: str) -> str:
    body = strip_sql_comments(sql)
    return re.sub(r"'(?:''|[^'])*'", "''", body)


def check(condition: bool, message: str) -> None:
    if not condition:
        fail(message)
    print(f"PASS: {message}")


source_csv = ROOT / "dataset" / "spotify_cleaned_dataset.csv"
raw_copy = ROOT / "data" / "raw" / "spotify_cleaned_dataset.csv"
check(source_csv.is_file(), "original CSV is present")
check(raw_copy.is_file(), "organized raw CSV copy is present")

source_hash = hashlib.sha256(source_csv.read_bytes()).hexdigest()
copy_hash = hashlib.sha256(raw_copy.read_bytes()).hexdigest()
check(source_hash == EXPECTED_SHA256, "original CSV matches its audited SHA-256")
check(copy_hash == source_hash, "organized CSV is byte-identical to original")

with source_csv.open("r", encoding="utf-8-sig", newline="") as source_file:
    reader = csv.reader(source_file)
    header = next(reader)
    row_count = sum(1 for _ in reader)
check(len(header) == EXPECTED_COLUMNS, "CSV has the audited 24-column shape")
check(row_count == EXPECTED_ROWS, "CSV has the audited 20,594 data rows")

schema_sql_path = ROOT / "sql" / "01_schema_and_profiling.sql"
schema_sql = schema_sql_path.read_text(encoding="utf-8")
table_match = re.search(
    r"CREATE TABLE IF NOT EXISTS spotify_raw\s*\((.*?)\);",
    schema_sql,
    flags=re.DOTALL | re.IGNORECASE,
)
check(table_match is not None, "raw-table DDL is present and non-destructive")
raw_columns = re.findall(
    r"^\s*([a-z_]+)\s+TEXT\s*,?\s*$",
    table_match.group(1),
    flags=re.MULTILINE | re.IGNORECASE,
)
check(
    [column.lower() for column in header]
    == [column.lower() for column in raw_columns],
    "raw-table column order matches CSV header order",
)
check(
    re.search(r"CREATE OR REPLACE VIEW spotify AS", schema_sql, re.IGNORECASE)
    is not None,
    "typed analysis view is declared",
)

sql_paths = sorted((ROOT / "sql").glob("*.sql"))
check(len(sql_paths) == 4, "four ordered SQL scripts are present")
all_sql = "\n".join(path.read_text(encoding="utf-8") for path in sql_paths)
executable_sql = static_sql_body(all_sql)
check(
    re.search(
        r"\b(DROP\s+TABLE|DELETE\s+FROM|TRUNCATE(?:\s+TABLE)?|UPDATE\s+spotify_raw)\b",
        executable_sql,
        flags=re.IGNORECASE,
    )
    is None,
    "new SQL scripts contain no destructive raw-data statements",
)

for path in sql_paths:
    body = static_sql_body(path.read_text(encoding="utf-8"))
    depth = 0
    for character in body:
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth < 0:
                fail(f"unbalanced SQL parentheses in {path.relative_to(ROOT)}")
    check(depth == 0, f"balanced parentheses in {path.relative_to(ROOT)}")
    check(
        body.rstrip().endswith(";"),
        f"SQL statements end with a semicolon in {path.relative_to(ROOT)}",
    )

business_sql = (ROOT / "sql" / "03_business_analysis.sql").read_text(
    encoding="utf-8"
)
question_count = len(re.findall(r"^\s*-- Q\d+\.", business_sql, flags=re.MULTILINE))
check(question_count == 17, "17 documented business questions are present")

for feature in (
    "ROW_NUMBER",
    "RANK",
    "DENSE_RANK",
    "LAG",
    "LEAD",
    "PARTITION BY",
    "CASE",
    "NULLIF",
    "GROUP BY",
    "ORDER BY",
    "CROSS JOIN",
):
    check(
        re.search(rf"\b{re.escape(feature)}\b", executable_sql, re.IGNORECASE)
        is not None,
        f"SQL demonstrates {feature}",
    )

unsupported_fields = (
    "genre",
    "region",
    "playlist",
    "release_date",
    "listener",
    "revenue",
    "track_id",
)
for field in unsupported_fields:
    check(
        re.search(rf"\b{field}\b", executable_sql, re.IGNORECASE) is None,
        f"SQL does not reference unsupported field {field}",
    )

required_paths = (
    ROOT / "docs" / "data_dictionary.md",
    ROOT / "docs" / "methodology.md",
    ROOT / "docs" / "interview_prep.md",
    ROOT / "results" / "README.md",
    ROOT / "tests" / "validate_portfolio.py",
    ROOT / "implementation_report.md",
)
for path in required_paths:
    check(path.is_file(), f"required project file exists: {path.relative_to(ROOT)}")

markdown_files = [ROOT / "README.md", *sorted((ROOT / "docs").glob("*.md"))]
local_links_checked = 0
for markdown_path in markdown_files:
    markdown = markdown_path.read_text(encoding="utf-8")
    for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", markdown):
        target = target.strip()
        if target.startswith(("https://", "http://", "mailto:")) or target.startswith("#"):
            continue
        relative_target = unquote(target.split("#", 1)[0])
        if not relative_target:
            continue
        linked_path = (markdown_path.parent / relative_target).resolve()
        check(
            linked_path.exists(),
            f"Markdown link resolves: {markdown_path.relative_to(ROOT)} -> {target}",
        )
        local_links_checked += 1
check(local_links_checked > 0, "local Markdown links were checked")

print("PASS: Static checks completed. These checks do not parse or execute PostgreSQL SQL.")
