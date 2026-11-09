#!/usr/bin/env bash
# Exécuté une seule fois par l'image postgres, au premier démarrage (volume vide).
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<SQL
-- Base source (bronze) et base de publication OMOP
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS gen;
CREATE DATABASE omop;

-- Rôle en lecture seule utilisé par ClickHouse pour répliquer le bronze
CREATE ROLE ch_reader LOGIN PASSWORD '${CH_READER_PASSWORD}';
GRANT CONNECT ON DATABASE ${POSTGRES_DB} TO ch_reader;
GRANT USAGE ON SCHEMA bronze TO ch_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze GRANT SELECT ON TABLES TO ch_reader;
SQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname omop <<SQL
-- Modèle de tables OMOP (vide) : sert de gabarit aux releases (CREATE TABLE ... (LIKE cdm_ddl.x))
CREATE SCHEMA IF NOT EXISTS cdm_ddl;
SQL

for f in /lab/postgres/omop/tables/*.sql; do
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname omop -c "SET search_path TO cdm_ddl;" -f "$f"
done
