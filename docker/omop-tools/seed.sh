#!/bin/bash
# Seeds the (empty) OMOP CDM with the Eunomia GiBleed synthetic dataset (Synthea based).
# Only the clinical tables are loaded, the vocabulary loaded by omop-init is kept.
set -euo pipefail

EUNOMIA_URL=${EUNOMIA_URL:-https://raw.githubusercontent.com/OHDSI/EunomiaDatasets/main/datasets/GiBleed/GiBleed_5.3.zip}
SEED_DIR=/install_db/eunomia
ZIP="$SEED_DIR/GiBleed_5.3.zip"

# Vocabulary tables and tables which are not part of CDM 5.4
SKIP_TABLES=" concept concept_ancestor concept_class concept_relationship concept_synonym domain drug_strength relationship vocabulary source_to_concept_map cohort cohort_attribute cdm_source "

if [ "$(psql -d omop -tAc "SELECT count(*) FROM (SELECT 1 FROM public.person LIMIT 1) p")" != "0" ]; then
    echo "OMOP CDM already contains persons, skipping demo data"
    exit 0
fi

mkdir -p "$SEED_DIR"
if [ ! -f "$ZIP" ]; then
    curl -fL --retry 3 -o "$ZIP.part" "$EUNOMIA_URL"
    mv "$ZIP.part" "$ZIP"
fi
rm -rf "$SEED_DIR/csv"
unzip -q -j -o "$ZIP" '*.csv' -x '__MACOSX/*' -d "$SEED_DIR/csv"

# The dataset is CDM 5.3, rename the columns which were renamed in CDM 5.4
rename_columns() {
    tr 'A-Z' 'a-z' | sed -e 's/admitting_source_/admitted_from_/g' \
        -e 's/discharge_to_/discharged_to_/g' \
        -e 's/visit_detail_parent_id/parent_visit_detail_id/g'
}

SCRIPT="$SEED_DIR/seed.sql"
cat > "$SCRIPT" <<'SQL'
\set ON_ERROR_STOP on
\o /dev/null
BEGIN;
-- The dataset references concepts which may not be in the loaded vocabulary; skip foreign key
-- checks so these show up as DQD findings instead of failing the load
SET session_replication_role = replica;

-- Insert the staged (text) columns which exist in the target table, cast to the target types
CREATE FUNCTION pg_temp.load_staged(target text) RETURNS void AS $$
DECLARE
    cols text;
    vals text;
    staged bigint;
    loaded bigint;
BEGIN
    SELECT string_agg(quote_ident(t.column_name), ', ' ORDER BY t.ordinal_position),
           string_agg(format('%I::%s', t.column_name, format_type(a.atttypid, a.atttypmod)), ', ' ORDER BY t.ordinal_position)
      INTO cols, vals
      FROM information_schema.columns t
      JOIN information_schema.columns s ON s.table_name = 'stg_' || target AND s.column_name = t.column_name
      JOIN pg_attribute a ON a.attrelid = ('public.' || target)::regclass AND a.attname = t.column_name
     WHERE t.table_schema = 'public' AND t.table_name = target;
    -- The dataset contains some duplicate ids, keep the first row
    EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM pg_temp.%I ON CONFLICT DO NOTHING', target, cols, vals, 'stg_' || target);
    GET DIAGNOSTICS loaded = ROW_COUNT;
    EXECUTE format('SELECT count(*) FROM pg_temp.%I', 'stg_' || target) INTO staged;
    RAISE NOTICE '%: % rows loaded (% duplicates skipped)', target, loaded, staged - loaded;
END $$ LANGUAGE plpgsql;
SQL

for csv in "$SEED_DIR"/csv/*.csv; do
    table=$(basename "$csv" .csv | tr 'A-Z' 'a-z')
    case "$SKIP_TABLES" in *" $table "*) continue ;; esac
    # Skip empty files and tables which do not exist in CDM 5.4
    [ "$(wc -l < "$csv")" -gt 1 ] || continue
    [ "$(psql -d omop -tAc "SELECT to_regclass('public.$table') IS NOT NULL")" = "t" ] || continue

    columns=$(head -1 "$csv" | tr -d '\r' | rename_columns | sed 's/,/ text, /g; s/$/ text/')
    cat >> "$SCRIPT" <<SQL
CREATE TEMP TABLE stg_$table ($columns);
\\copy stg_$table FROM '$csv' WITH (FORMAT csv, HEADER true)
SELECT pg_temp.load_staged('$table');
SQL
done

# Describe the demo dataset in cdm_source; the data is converted to CDM 5.4 while loading
cat >> "$SCRIPT" <<SQL
CREATE TEMP TABLE stg_cdm_source ($(head -1 "$SEED_DIR/csv/CDM_SOURCE.csv" | tr -d '\r' | rename_columns | sed 's/,/ text, /g; s/$/ text/'));
\\copy stg_cdm_source FROM '$SEED_DIR/csv/CDM_SOURCE.csv' WITH (FORMAT csv, HEADER true)
DELETE FROM public.cdm_source;
INSERT INTO public.cdm_source (
    cdm_source_name, cdm_source_abbreviation, cdm_holder, source_description, source_documentation_reference,
    cdm_etl_reference, source_release_date, cdm_release_date, cdm_version, cdm_version_concept_id, vocabulary_version
)
SELECT cdm_source_name || ' (Eunomia GiBleed demo)', cdm_source_abbreviation, cdm_holder, source_description,
       source_documentation_reference, cdm_etl_reference, source_release_date::date, current_date, 'v5.4', 756265,
       coalesce((SELECT vocabulary_version FROM public.vocabulary WHERE vocabulary_id = 'None'), vocabulary_version)
  FROM stg_cdm_source;
COMMIT;
SQL

echo "Loading Eunomia GiBleed demo data"
psql -d omop -q -f "$SCRIPT"
rm -rf "$SEED_DIR/csv"
psql -d omop -tAc "SELECT 'Demo data loaded: ' || count(*) || ' persons' FROM public.person"
