#!/usr/bin/env bash
# Fonctions communes aux scripts du lab. Toutes les connexions sont surchargeables par variables
# d'environnement (ex. pour viser un Postgres / ClickHouse hors Docker).
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$LAB_DIR"
if [[ -f .env ]]; then set -a; . ./.env; set +a; fi

# psql : par défaut dans le conteneur Postgres (aucun client à installer sur l'hôte)
PSQL_CMD="${PSQL_CMD:-docker compose exec -T postgres psql -U ${PG_USER:-lab}}"
# ClickHouse : interface HTTP (curl suffit)
CH_URL="${CH_URL:-http://localhost:${CH_HTTP_PORT:-8123}}"
CH_USER="${CH_USER:-dbt}"
CH_PASSWORD="${CH_PASSWORD:-}"

log()  { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die()  { printf '\033[1;31m[ERREUR]\033[0m %s\n' "$*" >&2; exit 1; }

# psql_db <base> [options psql...]
psql_db() { local db="$1"; shift; $PSQL_CMD -d "$db" -v ON_ERROR_STOP=1 -q "$@"; }

# ch_query <sql> [paramètres URL] : exécute une requête ClickHouse, résultat sur stdout
ch_query() {
  local sql="$1" params="${2:-}"
  printf '%s' "$sql" | curl -sS --fail-with-body \
    -H "X-ClickHouse-User: ${CH_USER}" -H "X-ClickHouse-Key: ${CH_PASSWORD}" \
    --data-binary @- "${CH_URL}/?${params}"
}

export -f log die psql_db ch_query
export LAB_DIR PSQL_CMD CH_URL CH_USER CH_PASSWORD
