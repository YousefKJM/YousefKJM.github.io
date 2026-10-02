---
title: "From Raw CSV to Trusted Dashboard: A Data Pipeline in Seven Steps"
excerpt: "Ingest, validate, clean, model, load, test, schedule — a complete small-scale data pipeline in Python and SQL, with the pandas and SQL patterns analysts reach for daily and the data-quality checks most pipelines forget."
---

Most data work isn't modelling — it's getting data into a state where anyone can trust a number on a dashboard. This is the pipeline shape I use for small-to-medium datasets, built with plain Python, pandas, and SQL before reaching for heavier tooling.

## The shape: bronze, silver, gold

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

**Why keep raw data untouched:** cleaning logic always has bugs. If you only stored the cleaned version, a bug destroys data permanently. With bronze intact, you fix the code and replay.

## Step 1 — Ingest to bronze, exactly as received

```python
import pandas as pd
from datetime import datetime, timezone

raw = pd.read_csv("exports/orders_2022-05.csv", dtype=str)   # read EVERYTHING as text first
raw["_loaded_at"]  = datetime.now(timezone.utc).isoformat()
raw["_source_file"] = "orders_2022-05.csv"
raw.to_parquet("bronze/orders/2022-05.parquet", index=False)
```

`dtype=str` is deliberate: if pandas guesses types, a product code like `007` becomes the integer `7` before you ever see it.

## Step 2 — Validate before you transform

Fail loudly, early, with a reason:

```python
def validate(df):
    errors = []
    required = {"order_id", "customer_id", "order_date", "amount"}
    if missing := required - set(df.columns):
        errors.append(f"missing columns: {missing}")
    if df["order_id"].isna().any():
        errors.append(f"{df['order_id'].isna().sum()} rows with no order_id")
    if df["order_id"].duplicated().any():
        errors.append(f"{df['order_id'].duplicated().sum()} duplicate order_ids")
    if (pd.to_numeric(df["amount"], errors="coerce") < 0).any():
        errors.append("negative amounts present")
    if errors:
        raise ValueError("Validation failed:\n  " + "\n  ".join(errors))
```

## Step 3 — Clean into silver

```python
df = pd.read_parquet("bronze/orders/2022-05.parquet")

df = (df
      .rename(columns=str.lower)
      .assign(
          order_date = lambda d: pd.to_datetime(d["order_date"], errors="coerce"),
          amount     = lambda d: pd.to_numeric(d["amount"], errors="coerce"),
          country    = lambda d: d["country"].str.strip().str.upper(),
      )
      .dropna(subset=["order_id", "order_date"])
      .drop_duplicates(subset="order_id", keep="last"))     # latest version of each order wins

df.to_parquet("silver/orders/2022-05.parquet", index=False)
```

Cleaning rules that pay off every time:

| Problem | Fix |
|---|---|
| `" sa"`, `"SA"`, `"Sa "` | `.str.strip().str.upper()` |
| Dates in three formats | `pd.to_datetime(..., errors="coerce")`, then count the `NaT`s you created |
| Duplicates from re-exports | Dedupe on the **business key**, not on the whole row |
| Silent `NaN`s from `coerce` | Log how many values you nulled — a jump means the source format changed |

## Step 4 — Model the gold layer (star schema)

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

**Facts** are events with numbers (orders, payments). **Dimensions** describe them (who, when, what). Dashboards slice facts by dimensions — this shape makes every one of those queries simple and fast.

## Step 5 — Load and query with SQL

```python
import sqlite3
con = sqlite3.connect("warehouse.db")
df.to_sql("silver_orders", con, if_exists="replace", index=False)
```

The SQL patterns worth knowing cold:

```sql
-- Monthly revenue with month-over-month growth (window function)
WITH monthly AS (
  SELECT strftime('%Y-%m', order_date) AS month, SUM(amount) AS revenue
  FROM silver_orders GROUP BY 1
)
SELECT month, revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly ORDER BY month;

-- Each customer's most recent order (deduplicate with ROW_NUMBER)
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
  FROM silver_orders
) WHERE rn = 1;

-- Running total per customer
SELECT customer_id, order_date, amount,
       SUM(amount) OVER (PARTITION BY customer_id ORDER BY order_date) AS running_total
FROM silver_orders;
```

`LAG`, `ROW_NUMBER`, and `SUM() OVER` cover a surprising share of real analytics questions.

## Step 6 — Test the data, not just the code

```python
def test_gold(con):
    q = lambda sql: con.execute(sql).fetchone()[0]
    assert q("SELECT COUNT(*) FROM silver_orders") > 0, "empty table"
    assert q("SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM silver_orders") == 0, "duplicate keys"
    assert q("SELECT COUNT(*) FROM silver_orders WHERE amount IS NULL") == 0, "null amounts"
    # Reconciliation: does the total still match the source file?
    src_total = pd.to_numeric(pd.read_parquet("bronze/orders/2022-05.parquet")["amount"], errors="coerce").sum()
    assert abs(q("SELECT SUM(amount) FROM silver_orders") - src_total) < 0.01, "totals drifted"
```

The reconciliation check is the one that catches the expensive bugs — a join that silently duplicated rows, or a filter that dropped a region.

## Step 7 — Make it idempotent, then schedule it

**Idempotent** = running it twice gives the same result as running it once. Partition by date and overwrite the partition rather than appending:

```bash
# cron: 02:00 every day, process yesterday's partition
0 2 * * * cd /opt/pipeline && python run.py --date "$(date -d yesterday +\%F)" >> logs/run.log 2>&1
```

When cron and scripts stop scaling — dependencies between jobs, retries, backfills — that's when a scheduler like Airflow earns its complexity. Not before.

## The checklist

- [ ] Raw data stored untouched, with load time and source
- [ ] Validation fails loudly with specific reasons
- [ ] Types parsed explicitly, never guessed
- [ ] Deduplication on the business key
- [ ] Facts and dimensions separated in the reporting layer
- [ ] Row-count, uniqueness, null, and reconciliation tests on every run
- [ ] Re-running a day produces the same result
