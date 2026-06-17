# Spark + Kafka + Postgres + DuckDB Sandbox

A local environment for practising real-time and batch data pipelines with PySpark, backed by Kafka, PostgreSQL, and DuckDB.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Docker network: sandbox                                        │
│                                                                 │
│  ┌──────────────┐   ┌──────────────┐                           │
│  │ spark-master │◄──│ spark-worker │  bitnami/spark:3.5        │
│  │  :8080 :7077 │   │  2G / 2 CPU  │                           │
│  └──────┬───────┘   └──────────────┘                           │
│         │ spark://spark-master:7077                             │
│  ┌──────▼───────┐                                              │
│  │   notebook   │  JupyterLab + PySpark + DuckDB               │
│  │  :8888 :4040 │  (built from Dockerfile)                     │
│  └──────┬───────┘                                              │
│         │                                                       │
│  ┌──────▼──────┐  ┌────────────┐  ┌──────────────────────┐    │
│  │    kafka    │  │ kafka-ui   │  │      postgres         │    │
│  │  :9092      │  │  :8090     │  │  :5432               │    │
│  │  (KRaft)    │  │            │  │  db: sandbox          │    │
│  └─────────────┘  └────────────┘  └──────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

  ./data/         ← shared volume (Parquet, Delta Lake, checkpoints)
  ./notebooks/    ← mounted into notebook container
```

---

## Services at a glance

| Service | URL / Host | Credentials |
|---|---|---|
| JupyterLab | http://localhost:8888 | token: `spark123` |
| Spark Master UI | http://localhost:8080 | — |
| Spark App UI | http://localhost:4040 | active while a job runs |
| Kafka UI | http://localhost:8090 | — |
| Kafka (broker) | `localhost:9092` | — |
| PostgreSQL | `localhost:5432` | user: `spark` / pw: `spark123` / db: `sandbox` |

---

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) ≥ 4.x (or Docker Engine + Compose plugin)
- At least **6 GB RAM** allocated to Docker
- VS Code with the [Jupyter extension](https://marketplace.visualstudio.com/items?itemName=ms-toolsai.jupyter) (optional, for notebook editing)

---

## Quick start

### 1 — Build and start

```bash
docker compose up --build
```

The first build downloads Spark JARs (Kafka connector, PostgreSQL JDBC, Delta Lake).  
This takes ~3–5 minutes once; subsequent starts are fast.

### 2 — Verify services are up

```bash
docker compose ps
```

All six containers should show `running` (healthy for postgres).

### 3 — Open JupyterLab

```
http://localhost:8888
```

Enter token **spark123** when prompted, then open `notebooks/00_getting_started.ipynb`.

### 4 — Stop everything

```bash
docker compose down          # keeps volumes (Kafka data, Postgres data)
docker compose down -v       # also wipes volumes (clean slate)
```

---

## Connecting from VS Code notebooks

1. Open any `.ipynb` file in VS Code.
2. Click **Select Kernel** (top right) → **Existing Jupyter Server**.
3. Enter: `http://localhost:8888?token=spark123`
4. Choose the **Python 3** kernel.

Your notebooks run inside the `notebook` container, which already has PySpark wired to the cluster and all packages installed.

---

## Using DuckDB

DuckDB is an **embedded analytical database** — no separate service, no connection string.  
It runs as a Python library inside the notebook container and is ideal for:

| Use case | Why DuckDB and not Spark |
|---|---|
| Query Parquet files after a Spark job | Millisecond latency, no cluster overhead |
| Ad-hoc exploration of small–medium data | No SparkSession startup cost |
| Sanity-checking Spark aggregation results | Run the same SQL on the same files |
| Building a lightweight local data warehouse | Persist a `.duckdb` file across sessions |

### Typical workflow

```python
import duckdb

con = duckdb.connect()  # in-memory; use duckdb.connect('my.db') to persist

# 1 — Query Parquet written by a Spark batch job
con.execute("""
    CREATE VIEW transactions AS
    SELECT * FROM read_parquet('/home/jupyter/data/output/transactions/**/*.parquet')
""")

# 2 — Analytical query — no Spark, no cluster
result = con.execute("""
    SELECT category,
           ROUND(SUM(amount), 2) AS revenue,
           COUNT(*)              AS tx_count
    FROM transactions
    WHERE status = 'completed'
    GROUP BY ALL
    ORDER BY revenue DESC
""").df()   # returns a pandas DataFrame
```

### Query PostgreSQL directly from DuckDB

```python
import duckdb, os

con = duckdb.connect()
con.execute("INSTALL postgres; LOAD postgres;")
con.execute(f"""
    ATTACH 'dbname=sandbox user=spark password=spark123 host=postgres port=5432'
    AS pg (TYPE POSTGRES)
""")

con.execute("SELECT * FROM pg.daily_summary LIMIT 10").df()
```

### Persistent DuckDB file (survives container restarts)

```python
# Stored under the mounted data volume — persists on the host
con = duckdb.connect('/home/jupyter/data/analytics.duckdb')
con.execute("CREATE TABLE IF NOT EXISTS results AS SELECT ...")
```

---

## Pipeline patterns to practice

### Batch pipeline

```
Faker / CSV / PostgreSQL
        ↓  (Spark read)
   Transform / Enrich
        ↓  (Spark write)
  Parquet / Delta Lake / PostgreSQL
        ↓  (DuckDB query)
   Analytics / Visualisation
```

### Real-time pipeline

```
Kafka producer (Python)
        ↓  kafka topic: transactions
   Spark Structured Streaming
        ↓  window aggregation
  Console / Parquet / PostgreSQL sink
```

### Lambda-style (both together)

```
Kafka ──► Spark Streaming ──► Delta Lake (streaming writes)
                                    ▲
PostgreSQL ──► Spark Batch ─────────┘  (batch backfill)
                                    ▼
                                DuckDB  (unified query layer)
```

---

## Useful commands

### Kafka

```bash
# List topics
docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list

# Create a topic manually
docker exec kafka kafka-topics \
  --bootstrap-server localhost:9092 \
  --create --topic my-topic --partitions 3 --replication-factor 1

# Tail messages from a topic
docker exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic transactions --from-beginning

# Describe consumer group lag
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 --describe --all-groups
```

### PostgreSQL

```bash
# Open psql inside the container
docker exec -it postgres psql -U spark -d sandbox

# Dump the database
docker exec postgres pg_dump -U spark sandbox > backup.sql
```

### Spark submit (outside notebook)

```bash
docker exec notebook spark-submit \
  --master spark://spark-master:7077 \
  /home/jupyter/notebooks/my_job.py
```

### Rebuild the notebook image after changing requirements.txt or Dockerfile

```bash
docker compose up --build notebook
```

---

## Project layout

```
.
├── docker-compose.yml          # All services
├── Dockerfile                  # notebook image: bitnami/spark + Jupyter + extras
├── requirements.txt            # Python packages installed in notebook image
├── spark-conf/
│   └── spark-defaults.conf     # AQE, Delta Lake, driver/executor memory
├── init-scripts/
│   └── 01_init.sql             # PostgreSQL schema + seed rows (runs on first start)
├── notebooks/
│   └── 00_getting_started.ipynb  # End-to-end walkthrough
└── data/
    ├── input/                  # Drop CSV / JSON files here to read in notebooks
    └── output/                 # Spark / DuckDB write targets
```

---

## Troubleshooting

**Container fails with `Address already in use`**  
Another process is using port 8888, 8080, 9092, or 5432.  
Edit the host-side port in `docker-compose.yml` (left side of `"host:container"`).

**Spark job hangs or OOMs**  
Increase `SPARK_WORKER_MEMORY` in `docker-compose.yml` and/or `spark.driver.memory` in `spark-conf/spark-defaults.conf`.

**Kafka UI shows no cluster**  
Kafka takes ~15 s to initialise. Refresh the page or run `docker compose logs kafka`.

**`ClassNotFoundException` for Kafka / JDBC / Delta**  
The JARs are downloaded during `docker build`. Run `docker compose up --build notebook` to force a rebuild.

**`CLUSTER_ID` mismatch error from Kafka**  
The `kafka-data` volume has stale metadata. Run `docker compose down -v` to wipe it, then restart.
