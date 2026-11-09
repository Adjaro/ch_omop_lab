#!/usr/bin/env bash
# =====================================================================
# Publie une RELEASE OMOP FIGÉE : ClickHouse (gold_omop) -> PostgreSQL (base omop).
#   1. crée un schéma cdm_AAAAMMJJ_HHMMSS
#   2. charge les tables EN PARALLÈLE (COPY en flux, sans fichier intermédiaire ;
#      table créée dans la même transaction que le COPY => pas de WAL avec wal_level=minimal)
#   3. crée PK + index OHDSI APRÈS chargement, puis ANALYZE
#   4. contrôle les volumes ClickHouse vs Postgres (annule tout en cas d'écart)
#   5. bascule atomique : l'ancien "cdm" est archivé, la nouvelle release devient "cdm"
#   6. ne garde que les KEEP_RELEASES dernières releases archivées
# Les outils OHDSI pointent toujours sur le schéma "cdm" : aucune reconfiguration.
# =====================================================================
source "$(dirname "$0")/lib.sh"

PG_DB_OMOP="${PG_DB_OMOP:-omop}"
KEEP_RELEASES="${KEEP_RELEASES:-1}"
PARALLEL="${PARALLEL:-4}"
REL="cdm_$(date +%Y%m%d_%H%M%S)"
# Les plus grosses tables d'abord : meilleure répartition du parallélisme
TABLES=(measurement drug_exposure condition_occurrence procedure_occurrence visit_occurrence
        observation_period person death care_site cdm_source)

log "Release $REL — contrôles préalables"
ch_query "SELECT 1" >/dev/null || die "ClickHouse injoignable sur $CH_URL"

psql_db "$PG_DB_OMOP" <<'SQL'
CREATE TABLE IF NOT EXISTS public.omop_release (
    release_schema text PRIMARY KEY,
    published_at   timestamptz,
    status         text NOT NULL,          -- active | archived | rolled_back | dropped
    row_counts     jsonb
);
SQL

declare -A EXPECTED
for t in "${TABLES[@]}"; do
  EXPECTED[$t]=$(ch_query "SELECT count() FROM gold_omop.$t FINAL WHERE _is_deleted = 0")
done

cleanup_on_error() {
  log "Échec : suppression du schéma $REL (la release active n'est pas touchée)"
  psql_db "$PG_DB_OMOP" -c "DROP SCHEMA IF EXISTS $REL CASCADE" || true
}
trap cleanup_on_error ERR

psql_db "$PG_DB_OMOP" -c "CREATE SCHEMA $REL"

load_table() {
  set -euo pipefail
  local t="$1" cols t0=$SECONDS
  cols=$(psql_db "$PG_DB_OMOP" -tA -c "SELECT string_agg(column_name, ',' ORDER BY ordinal_position)
                                        FROM information_schema.columns
                                        WHERE table_schema = 'cdm_ddl' AND table_name = '$t'")
  [[ -n "$cols" ]] || { echo "Table $t absente du gabarit cdm_ddl" >&2; return 1; }
  {
    printf 'BEGIN;\nCREATE TABLE %s.%s (LIKE cdm_ddl.%s INCLUDING DEFAULTS);\nCOPY %s.%s (%s) FROM STDIN;\n' \
           "$REL" "$t" "$t" "$REL" "$t" "$cols"
    if ch_query "SELECT $cols FROM gold_omop.$t FINAL WHERE _is_deleted = 0 FORMAT TabSeparated" \
                "max_threads=8&output_format_parallel_formatting=1"; then
      printf '\\.\nCOMMIT;\n'
    else
      printf '\\.\nROLLBACK;\n'; exit 1
    fi
  } | psql_db "$PG_DB_OMOP"
  log "  $t chargée en $((SECONDS - t0)) s"
}
export -f load_table
export REL PG_DB_OMOP

log "Chargement parallèle ($PARALLEL flux) ClickHouse -> Postgres…"
t0=$SECONDS
printf '%s\n' "${TABLES[@]}" | xargs -P "$PARALLEL" -I{} bash -c 'load_table "$1"' _ {}
log "Chargement terminé en $((SECONDS - t0)) s"

log "Clés primaires + index OHDSI…"
t0=$SECONDS
psql_db "$PG_DB_OMOP" -v schema="$REL" < postgres/omop/indexes.sql
for t in "${TABLES[@]}"; do echo "ANALYZE $REL.$t;"; done | psql_db "$PG_DB_OMOP"
log "Index + statistiques en $((SECONDS - t0)) s"

log "Contrôle des volumes ClickHouse vs Postgres…"
counts_json="{"
for t in "${TABLES[@]}"; do
  got=$(psql_db "$PG_DB_OMOP" -tA -c "SELECT count(*) FROM $REL.$t")
  [[ "$got" == "${EXPECTED[$t]}" ]] || die "Écart sur $t : ClickHouse=${EXPECTED[$t]} Postgres=$got"
  printf '  %-22s %12s lignes\n' "$t" "$got" >&2
  counts_json+="\"$t\":$got,"
done
counts_json="${counts_json%,}}"

log "Bascule atomique vers $REL…"
psql_db "$PG_DB_OMOP" -v rel="$REL" -v counts="$counts_json" <<'SQL'
BEGIN;
DO $$
DECLARE prev text;
BEGIN
  SELECT release_schema INTO prev FROM public.omop_release WHERE status = 'active';
  IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'cdm') THEN
    EXECUTE format('ALTER SCHEMA cdm RENAME TO %I',
                   coalesce(prev, 'cdm_legacy_' || to_char(now(), 'YYYYMMDD_HH24MISS')));
  END IF;
  UPDATE public.omop_release SET status = 'archived' WHERE status = 'active';
END $$;
ALTER SCHEMA :"rel" RENAME TO cdm;
INSERT INTO public.omop_release (release_schema, published_at, status, row_counts)
VALUES (:'rel', now(), 'active', :'counts'::jsonb);
COMMIT;
SQL
trap - ERR

log "Rétention : conservation des $KEEP_RELEASES dernières releases archivées"
psql_db "$PG_DB_OMOP" -v keep="$KEEP_RELEASES" <<'SQL'
SELECT set_config('lab.keep', :'keep', false) \gset
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT release_schema FROM public.omop_release
           WHERE status IN ('archived', 'rolled_back')
           ORDER BY published_at DESC OFFSET current_setting('lab.keep')::int
  LOOP
    EXECUTE format('DROP SCHEMA IF EXISTS %I CASCADE', r.release_schema);
    UPDATE public.omop_release SET status = 'dropped' WHERE release_schema = r.release_schema;
  END LOOP;
END $$;
SQL

psql_db "$PG_DB_OMOP" -c "SELECT release_schema, published_at, status FROM public.omop_release ORDER BY published_at DESC LIMIT 6"
log "Release $REL publiée : schéma 'cdm' à jour"
