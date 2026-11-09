#!/usr/bin/env bash
# Génère le bronze FICTIF dans Postgres (base eds, schéma bronze).
#   ./scripts/generate_data.sh [scale]     (défaut : SCALE du .env ; 1 ≈ 5 Go)
# Les 7 tables sont générées EN PARALLÈLE, index et statistiques créés ensuite.
source "$(dirname "$0")/lib.sh"

SCALE_ARG="${1:-${SCALE:-1}}"
GEN_DIR="${GEN_DIR:-/lab/postgres/generate}"     # chemin vu par psql (dans le conteneur)
[[ "$PSQL_CMD" != docker* ]] && GEN_DIR="${GEN_DIR_LOCAL:-$LAB_DIR/postgres/generate}"

run_sql() { psql_db eds -v scale="$SCALE_ARG" -f "$GEN_DIR/$1"; }

log "Préparation (scale=$SCALE_ARG) : fonctions de génération + référentiel de mapping"
run_sql 00_prepare.sql

log "Génération parallèle des tables bronze…"
start=$SECONDS
pids=()
for f in 10_pa_pat.sql 11_pa_pas.sql 12_pa_res_pat.sql 13_diag.sql 14_actes.sql 15_bio.sql 16_pharma.sql; do
  run_sql "$f" & pids+=($!)
done
rc=0
for p in "${pids[@]}"; do wait "$p" || rc=1; done
(( rc == 0 )) || die "échec de la génération (voir messages ci-dessus)"
log "Tables générées en $((SECONDS - start)) s"

log "Clés primaires, index (B-tree + BRIN) et statistiques…"
start=$SECONDS
run_sql 90_finalize.sql
log "Finalisation en $((SECONDS - start)) s"
