#!/bin/bash
# Creates the OMOP CDM database (structure + vocabulary) when it does not exist yet,
# and (re)applies the idempotent post-install SQL in /sql/post on every start.
set -euo pipefail

CDM_DDL_BASE="https://raw.githubusercontent.com/OHDSI/CommonDataModel/refs/tags/v5.4.0/inst/ddl/5.4/postgresql"
INSTALL_DIR=/install_db
VOCAB_ZIP="$INSTALL_DIR/omop_terminology_package.zip"

until pg_isready -q; do sleep 2; done

concept_rows() {
    psql -d omop -tAc "SELECT CASE WHEN to_regclass('public.concept') IS NULL THEN 0 ELSE (SELECT count(*) FROM (SELECT 1 FROM public.concept LIMIT 1) c) END" 2>/dev/null || echo 0
}

if [ "$(psql -tAc "SELECT count(*) FROM pg_database WHERE datname = 'omop'")" = "1" ] && [ "$(concept_rows)" != "0" ]; then
    echo "OMOP CDM database already present, skipping structure and vocabulary load"
else
    if [ "$(psql -tAc "SELECT count(*) FROM pg_database WHERE datname = 'omop'")" = "1" ]; then
        echo "Database omop exists but has no vocabulary; remove it (docker compose down -v) and restart" >&2
        exit 1
    fi

    # Download the OMOP database structure
    mkdir -p "$INSTALL_DIR/01_structure" "$INSTALL_DIR/02_terminologies"
    cd "$INSTALL_DIR/01_structure"
    for part in ddl indices constraints primary_keys; do
        curl -fsSL --retry 3 -o "omop_${part}.sql" "$CDM_DDL_BASE/OMOPCDM_postgresql_5.4_${part}.sql"
        # Fix the CDM schema name
        sed -i 's/@cdmDatabaseSchema/public/g' "omop_${part}.sql"
    done
    mv omop_indices.sql omop_indexes.sql

    # Download and extract the omop terminology zip (kept in the volume as download cache)
    if [ ! -f "$VOCAB_ZIP" ]; then
        echo "Downloading vocabulary from $VOCAB_URL"
        curl -fL --retry 3 -o "$VOCAB_ZIP.part" "$VOCAB_URL"
        mv "$VOCAB_ZIP.part" "$VOCAB_ZIP"
    fi
    cd "$INSTALL_DIR/02_terminologies"
    unzip -o -q "$VOCAB_ZIP"
    cp /setup_files/load_terms.sql ./
    cp /setup_files/setup_database.sql "$INSTALL_DIR/"
    chmod -R a+rX "$INSTALL_DIR"

    # COPY statements run server side, so the postgres container mounts the same volume at /install_db.
    # Not every vocabulary package satisfies all CDM constraints, so errors do not stop the load;
    # the vocabulary itself is verified afterwards.
    echo "Loading OMOP CDM structure and vocabulary, this can take a while"
    psql -f "$INSTALL_DIR/setup_database.sql"
    if [ "$(concept_rows)" = "0" ]; then
        echo "Loading the vocabulary failed, dropping database omop" >&2
        dropdb --if-exists omop
        exit 1
    fi

    # Only keep the downloaded zip, the extracted files are large
    find "$INSTALL_DIR/02_terminologies" -name '*.csv' -delete
fi

for f in /sql/post/*.sql; do
    [ -e "$f" ] || continue
    echo "Applying $(basename "$f")"
    psql -v ON_ERROR_STOP=1 -d omop \
        -v dqd_password="${DQD_PASSWORD:-}" \
        -v superset_db_password="${SUPERSET_DB_PASSWORD:-}" \
        -v superset_reader_password="${SUPERSET_READER_PASSWORD:-}" \
        -f "$f"
done

echo "OMOP CDM database ready"
