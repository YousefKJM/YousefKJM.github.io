---
title: "Building a Data Pipeline from Raw CSV to a Trusted Report"
excerpt: "In this article I would like to present how to build a small but complete data pipeline in Python and SQL — ingest, validate, clean, model, query, test and schedule — using a messy export as the example, including a date-parsing bug that passed every test until one more check was added."
header:
  image: /images/posts/data-pipeline/monthly_revenue.png
---

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 190" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Pipeline layers: sources land untouched in bronze raw storage, are validated and cleaned into silver, then modeled into gold aggregate tables that feed dashboards">
  <defs><marker id="de-arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="var(--text-muted)"/></marker></defs>
  <g style="font-size:12px;">
    <rect x="5" y="40" width="105" height="90" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="18" y="64" font-weight="700" fill="var(--text)">Sources</text>
    <text x="18" y="84" fill="var(--text-muted)">CSV / API</text>
    <text x="18" y="102" fill="var(--text-muted)">app DB</text>
    <text x="18" y="120" fill="var(--text-muted)">exports</text>
    <rect x="140" y="40" width="140" height="90" rx="8" fill="var(--bg-elevated-2)" stroke="#b08d57" stroke-width="2"/>
    <text x="153" y="64" font-weight="700" fill="#b08d57">BRONZE · raw</text>
    <text x="153" y="84" fill="var(--text-muted)">exactly as received</text>
    <text x="153" y="102" fill="var(--text-muted)">append-only</text>
    <text x="153" y="120" fill="var(--text-muted)">+ load timestamp</text>
    <rect x="310" y="40" width="140" height="90" rx="8" fill="var(--bg-elevated-2)" stroke="var(--text-muted)" stroke-width="2"/>
    <text x="323" y="64" font-weight="700" fill="var(--text)">SILVER · clean</text>
    <text x="323" y="84" fill="var(--text-muted)">typed, deduped</text>
    <text x="323" y="102" fill="var(--text-muted)">validated</text>
    <text x="323" y="120" fill="var(--text-muted)">one row = one thing</text>
    <rect x="480" y="40" width="155" height="90" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="493" y="64" font-weight="700" fill="var(--accent)">GOLD · business</text>
    <text x="493" y="84" fill="var(--text-muted)">aggregates, KPIs</text>
    <text x="493" y="102" fill="var(--text-muted)">star schema</text>
    <text x="493" y="120" fill="var(--text-muted)">→ dashboards</text>
    <line x1="110" y1="85" x2="136" y2="85" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#de-arr)"/>
    <line x1="280" y1="85" x2="306" y2="85" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#de-arr)"/>
    <line x1="450" y1="85" x2="476" y2="85" stroke="var(--text-muted)" stroke-width="2" marker-end="url(#de-arr)"/>
    <text x="140" y="165" fill="var(--text-muted)">Never edit bronze. If silver logic has a bug, fix it and rebuild from bronze.</text>
  </g>
</svg>
</div>

<h3><strong>Short introduction</strong></h3>
Most data work is not machine learning. It is getting data into a state where people can trust the numbers on a report. Exports arrive with duplicate rows, inconsistent spelling and dates in different formats, and every one of those problems ends up as a wrong number on a dashboard if nobody catches it. In this article I would like to present the pipeline structure I use for small and medium datasets, built only with Python, pandas and SQL. To make it concrete, I ran every step on a deliberately messy sample export of 625 orders — and it caught a bug I didn't expect.

&nbsp;
<h3><strong>The structure: bronze, silver and gold</strong></h3>
The diagram at the top shows the three layers:

- **Bronze** — the raw data, exactly as received, never changed.
- **Silver** — cleaned data: correct types, no duplicates, validated.
- **Gold** — business-ready tables and aggregates that feed reports.

> **_NOTE:_**  Why keep the raw data untouched? Because cleaning code always has bugs. If you only keep the cleaned version, a bug destroys data forever. With bronze kept as it is, you fix the code and run it again. As you will see below, this is not a theoretical problem.

&nbsp;
<h3><strong>Step 1 — Ingest to bronze</strong></h3>
Lets start by saving the export exactly as it is, with two extra columns that tell us when and from where it was loaded:

```python
import pandas as pd
from datetime import datetime, timezone

raw = pd.read_csv("exports/orders_2022-05.csv", dtype=str)   # read everything as text first
raw["_loaded_at"]   = datetime.now(timezone.utc).isoformat()
raw["_source_file"] = "orders_2022-05.csv"
raw.to_parquet("bronze/orders/2022-05.parquet", index=False)
```

`dtype=str` is on purpose: if pandas guesses types, a code like `007` becomes the number `7` before you ever see it.

&nbsp;
<h3><strong>Step 2 — Validate before transforming</strong></h3>
The pipeline should stop early, with a clear reason, when a file is broken:

```python
def validate(df):
    errors = []
    required = {"order_id", "customer_id", "order_date", "amount"}
    if missing := required - set(df.columns):
        errors.append(f"missing columns: {missing}")
    if df["order_id"].isna().any():
        errors.append(f"{df['order_id'].isna().sum()} rows with no order_id")
    if (pd.to_numeric(df["amount"], errors="coerce") < 0).any():
        errors.append("negative amounts present")
    if errors:
        raise ValueError("Validation failed:\n  " + "\n  ".join(errors))
```

This is the real output when I gave it a broken export with a missing order id and a negative amount:

```
Validation failed:
  1 rows with no order_id
  negative amounts present
```

&nbsp;
<h3><strong>Step 3 — Clean into silver (and the bug)</strong></h3>
The sample export has three typical problems: 25 re-exported duplicate rows, country codes written as `"SA"`, `" sa"` and `"Sa "`, and dates in two formats (`2022-03-24` and `24/03/2022`).

The dates are the interesting part. These are the real results (pandas 1.5) of two ways to parse them:

```
pd.to_datetime(dates, errors="coerce")
  -> 1 NaT, but latest date = 2022-12-05
  -> 56 dates have day and month swapped

two explicit formats, one after the other
  -> 1 NaT, range 2022-01-01 .. 2022-05-31
```

1. The first one looked perfect: only one bad date — the real `not-a-date` row in the file. But for every `dd/mm/yyyy` value where the day is 12 or less, pandas guessed month-first, so `03/02/2022` became the <strong>2nd of March</strong> instead of the 3rd of February. The export only covers January to May, but revenue appeared in June to December. Pandas did print a `UserWarning` — which nobody reads in a scheduled job at 2 a.m.
2. Parsing each known format explicitly gave correct dates.

So this is the cleaning step:

```python
def parse_dates(s):
    iso = pd.to_datetime(s, format="%Y-%m-%d", errors="coerce")     # try each known format explicitly
    dmy = pd.to_datetime(s, format="%d/%m/%Y", errors="coerce")
    return iso.fillna(dmy)

df = pd.read_parquet("bronze/orders/2022-05.parquet")
df = (df
      .rename(columns=str.lower)
      .assign(
          order_date = lambda d: parse_dates(d["order_date"]),
          amount     = lambda d: pd.to_numeric(d["amount"], errors="coerce"),
          country    = lambda d: d["country"].str.strip().str.upper(),
      )
      .dropna(subset=["order_id", "order_date"])
      .drop_duplicates(subset="order_id", keep="last"))         # latest version of each order wins
df.to_parquet("silver/orders/2022-05.parquet", index=False)
```

Result: 625 bronze rows became <strong>599 silver rows</strong> (25 duplicates and 1 unreadable date removed), and the country codes became exactly `AE`, `BH`, `KW` and `SA`.

&nbsp;
<h3><strong>Step 4 — Model the gold layer</strong></h3>
For reporting, the gold layer uses a <strong>star schema</strong>:

<div style="margin:2rem 0;padding:1.25rem;background:var(--bg-elevated);border:1px solid var(--border);border-radius:var(--radius-m);">
<svg viewBox="0 0 640 220" style="width:100%;height:auto;font-family:inherit;" role="img" aria-label="Star schema: a central fact_orders table of measures and foreign keys, surrounded by dimension tables for customer, date, and product">
  <g style="font-size:12px;">
    <line x1="320" y1="110" x2="120" y2="45" stroke="var(--border)" stroke-width="2"/>
    <line x1="320" y1="110" x2="520" y2="45" stroke="var(--border)" stroke-width="2"/>
    <line x1="320" y1="110" x2="320" y2="190" stroke="var(--border)" stroke-width="2"/>
    <rect x="235" y="75" width="170" height="70" rx="8" fill="var(--bg-elevated-2)" stroke="var(--accent)" stroke-width="2"/>
    <text x="250" y="97" font-weight="700" fill="var(--accent)">fact_orders</text>
    <text x="250" y="115" fill="var(--text-muted)">order_id, amount, qty</text>
    <text x="250" y="133" fill="var(--text-muted)">customer_key, date_key</text>
    <rect x="40" y="15" width="160" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="54" y="38" font-weight="700" fill="var(--text)">dim_customer</text>
    <text x="54" y="56" fill="var(--text-muted)">name, segment, country</text>
    <rect x="440" y="15" width="160" height="56" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="454" y="38" font-weight="700" fill="var(--text)">dim_date</text>
    <text x="454" y="56" fill="var(--text-muted)">day, month, quarter, FY</text>
    <rect x="240" y="165" width="160" height="50" rx="8" fill="var(--bg-elevated-2)" stroke="var(--border)"/>
    <text x="254" y="187" font-weight="700" fill="var(--text)">dim_product</text>
    <text x="254" y="204" fill="var(--text-muted)">category, brand</text>
  </g>
</svg>
</div>

<strong>Facts</strong> are events with numbers (orders, payments). <strong>Dimensions</strong> describe them (who, when, what). Reports slice facts by dimensions, and this structure keeps those queries simple and fast.

&nbsp;
<h3><strong>Step 5 — Load and query with SQL</strong></h3>
In this section we will load the silver data into a database and answer real questions with SQL:

```python
import sqlite3
con = sqlite3.connect("warehouse.db")
df.to_sql("silver_orders", con, if_exists="replace", index=False)
```

Monthly revenue with month-over-month growth, using the `LAG` window function:

```sql
WITH monthly AS (
  SELECT strftime('%Y-%m', order_date) AS month, SUM(amount) AS revenue
  FROM silver_orders GROUP BY 1
)
SELECT month, ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly ORDER BY month;
```

```
  month  revenue  mom_growth_pct
2022-01 56435.70             NaN
2022-02 49384.90           -12.5
2022-03 55957.40            13.3
2022-04 48029.26           -14.2
2022-05 61793.76            28.7
```

And the same result as a chart for the report:

<img src="/images/posts/data-pipeline/monthly_revenue.png" alt="Monthly revenue chart" style="margin-inline:auto;" />

Two more patterns worth knowing by heart — the latest order of each customer with `ROW_NUMBER`, and a running total with `SUM() OVER`:

```sql
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
  FROM silver_orders
) WHERE rn = 1;

SELECT customer_id, order_date, amount,
       SUM(amount) OVER (PARTITION BY customer_id ORDER BY order_date) AS running_total
FROM silver_orders;
```

&nbsp;
<h3><strong>Step 6 — Test the data, not only the code</strong></h3>
Every run ends with data tests:

```python
q = lambda sql: con.execute(sql).fetchone()[0]
checks = {
  "table not empty":    q("SELECT COUNT(*) FROM silver_orders") > 0,
  "no duplicate keys":  q("SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM silver_orders") == 0,
  "no null amounts":    q("SELECT COUNT(*) FROM silver_orders WHERE amount IS NULL") == 0,
  "dates inside the export window":
      q("SELECT COUNT(*) FROM silver_orders WHERE order_date NOT BETWEEN '2022-01-01' AND '2022-05-31'") == 0,
  "totals reconcile with bronze": abs(q("SELECT SUM(amount) FROM silver_orders") - bronze_total) < 0.01,
}
```

```
  PASS  table not empty
  PASS  no duplicate keys
  PASS  no null amounts
  PASS  dates inside the export window
  PASS  totals reconcile with bronze
```

> **_NOTE:_**  Here is the important lesson from step 3: with the swapped dates, the first three checks <strong>and the reconciliation check all passed</strong> — the total was correct, only the months were wrong. The "dates inside the export window" check is the one that catches it. Add range checks for every date and amount column, not only totals.

&nbsp;
<h3><strong>Step 7 — Make it repeatable and schedule it</strong></h3>
A pipeline should be <strong>idempotent</strong>: running it twice gives the same result as running it once. Process one date partition at a time and overwrite it, instead of appending. Then schedule it:

```bash
# cron: every day at 02:00, process yesterday's partition
0 2 * * * cd /opt/pipeline && python run.py --date "$(date -d yesterday +\%F)" >> logs/run.log 2>&1
```

When cron and scripts are no longer enough — dependencies between jobs, retries, backfills — that is the right moment for a scheduler like Apache Airflow. Not before.

&nbsp;
<h3><strong>Summary</strong></h3>
A trustworthy pipeline keeps raw data untouched, validates early, parses types explicitly, removes duplicates by the business key, separates facts and dimensions, and tests the data on every run. The date bug in this example is a good reminder of why: it looked correct, passed the usual checks, and would have shown revenue in months that never happened. You can read more about date parsing in the <a href="https://pandas.pydata.org/docs/reference/api/pandas.to_datetime.html" target="_blank" rel="noopener">pandas documentation</a>.
