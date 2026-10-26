"""Build the earnings estimator end to end.

    python data/generate.py     # once, creates data/raw/
    python run_pipeline.py      # runs sql/00..08 and sql/checks.sql, writes outputs/

Everything runs locally in DuckDB. No database or credentials needed.
"""
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent
SQL = ROOT / "sql"
OUT = ROOT / "outputs"
STEPS = sorted(SQL.glob("0*.sql")) + [SQL / "checks.sql"]


def build(db_path: str = ":memory:") -> duckdb.DuckDBPyConnection:
    con = duckdb.connect(db_path)
    con.execute(f"SET file_search_path = '{ROOT.as_posix()}'")
    for step in STEPS:
        con.execute(step.read_text(encoding="utf-8"))
    return con


def main() -> None:
    con = build()
    OUT.mkdir(exist_ok=True)
    for table in ["estimates", "levers", "cell_bands", "peer_benchmarks", "data_checks"]:
        con.table(table).df().to_csv(OUT / f"{table}.csv", index=False)

    print("Data checks\n" + "-" * 84)
    for row in con.execute(
        "SELECT check_id, check_name, ROUND(naive_value, 2), ROUND(model_value, 2) FROM data_checks ORDER BY 1"
    ).fetchall():
        print(f"{row[0]}. {row[1]:<42} naive {row[2]:>12,}   model {row[3]:>12,}")

    print("\nLevers\n" + "-" * 84)
    print(con.table("levers").df().to_string(index=False))

    n_est = con.execute("SELECT COUNT(*) FROM estimates").fetchone()[0]
    print(f"\n{n_est} estimate rows written to outputs/estimates.csv")


if __name__ == "__main__":
    main()
