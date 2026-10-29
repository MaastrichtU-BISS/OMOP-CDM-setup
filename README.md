# OMOP CDM setup

This repository creates an OMOP CDM 5.4 database in a postgres docker container, checks its data quality with the
[OHDSI Data Quality Dashboard](https://ohdsi.github.io/DataQualityDashboard/) (DQD) on a schedule, and shows the results
in an [Apache Superset](https://superset.apache.org/) dashboard.

## Prerequisites
* Docker with Docker Compose v2.20 or newer (please find installation [here](https://docs.docker.com/get-docker/))

## Setup
Please download/checkout this repository, and run the [./setup.sh](./setup.sh) file (or `docker compose up -d --build`).
To also load demo data, run `./setup.sh --profile demo`.

Settings (passwords, DQD schedule, vocabulary download) can be changed by copying [.env.example](./.env.example) to
`.env` before the first start.

On the first start the `omop-init` container downloads the CDM structure and the vocabulary and loads them into an
`omop` database. This takes a while; follow the progress with `docker compose logs -f omop-init`. On later starts the
existing database is kept.

To remove everything, including all data, run [./teardown.sh](./teardown.sh).

## Services

| Service | Description | Address |
| --- | --- | --- |
| postgres | OMOP CDM database (`omop`, CDM in schema `public`, DQD results in schema `dqd_results`) | localhost:5432 |
| omop-init | One-shot: loads the CDM structure and vocabulary, creates roles and the results schema | |
| seed | One-shot, profile `demo` only: loads the [Eunomia GiBleed](https://github.com/OHDSI/EunomiaDatasets) synthetic data (2,694 persons) into an empty CDM | |
| dqd | Runs the DQD checks on start and on a schedule | |
| superset-init | One-shot: prepares Superset and imports the dashboard | |
| superset | Data quality dashboard | [http://localhost:8088](http://localhost:8088) |
| pgadmin | Postgres web interface | [http://localhost:5555](http://localhost:5555) |

### Postgres
* hostname: postgres (or localhost:5432 from the host machine)
* username: postgres
* password: postgres

### pgAdmin
Sign in with the following credentials:
* Username: admin@omop.tld
* Password: 1234567890

The postgres database server is preconfigured as "OMOP" (under "Servers"), including its credentials (see
[setup_files/pgadmin](./setup_files/pgadmin)).

### Superset
Sign in with username `admin` and password `admin`, and open the "OMOP Data Quality" dashboard. It shows the latest DQD
run (pass rate, results per Kahn category and context, failed checks per CDM table and a list of all failed checks) and
the trend over all runs.

The dashboard is imported from [docker/superset/assets](./docker/superset/assets) on every start, which overwrites
changes made to it in the UI. To keep changes, export the dashboard (dashboard menu "Download" > "Export YAML"),
replace the contents of `docker/superset/assets` with the contents of the exported zip, and rebuild with
`docker compose up -d --build`.

Superset reads the database with the read-only `superset_reader` role, so new charts can also use the CDM tables.

## Data quality checks (DQD)
The `dqd` container runs the checks when it starts and on the schedule in `DQD_SCHEDULE` (cron, UTC, default
`0 2 * * *`: every night at 02:00). To run the checks right away:

```
docker compose exec dqd /app/run_dqd.sh
```

Every run is registered in `dqd_results.run_log` and its results are stored in `dqd_results.check_results_history`.
The views `dqd_results.v_check_results` and `dqd_results.v_run_summary` are used by the dashboard. The JSON output of
each run, which can be opened with the DQD viewer, is kept in the `dqd_output` volume.

Note: the cohort tables are excluded from the checks, as they contain analysis results instead of source data.

## Demo data
The `demo` profile loads the clinical tables of the Eunomia GiBleed dataset (CDM 5.3, converted to 5.4 while loading)
when the CDM does not contain any persons yet. The vocabulary of the dataset is not loaded; its concepts may not all
be in the loaded vocabulary, which shows up in the data quality checks.
