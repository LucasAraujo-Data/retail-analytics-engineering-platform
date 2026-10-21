"""Run retail data loading (only when empty) and dbt models inside Docker."""
import os
import subprocess
import sys
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    print("RUN:", " ".join(map(str, args)), flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    host = os.environ.get("POSTGRES_HOST", "postgres")
    port = int(os.environ.get("POSTGRES_PORT", "5432"))
    with psycopg.connect(
        host=host, port=port,
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    ) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM raw.orders")
            has_orders = cur.fetchone()[0] > 0
    mode = "validate" if has_orders else "rebuild"
    loader = [sys.executable, "scripts/load_retail_data.py", "--mode", mode]
    if mode == "rebuild":
        loader += ["--orders", os.environ.get("PIPELINE_ORDERS", "15000"),
                   "--seed", os.environ.get("PIPELINE_SEED", "42")]
    run(*loader)
    run("dbt", "deps", "--project-dir", "dbt", "--profiles-dir", "dbt")
    run("dbt", "build", "--project-dir", "dbt", "--profiles-dir", "dbt")
    print("PIPELINE COMPLETED: PostgreSQL, Python, dbt and tests.", flush=True)


if __name__ == "__main__":
    main()
