#!/usr/bin/env bash
# Simule un nouveau lot d'ingestion dans le bronze Postgres (nouveaux séjours, corrections,
# décès, oppositions). Ensuite : `make dbt` pour voir l'incrémental à l'œuvre.
source "$(dirname "$0")/lib.sh"

GEN_DIR="${GEN_DIR:-/lab/postgres/generate}"
[[ "$PSQL_CMD" != docker* ]] && GEN_DIR="${GEN_DIR_LOCAL:-$LAB_DIR/postgres/generate}"

log "Ingestion d'un nouveau lot dans bronze…"
psql_db eds -f "$GEN_DIR/50_increment.sql"
