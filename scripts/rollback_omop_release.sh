#!/usr/bin/env bash
# Revient instantanément à la release précédente (échange atomique des schémas).
source "$(dirname "$0")/lib.sh"
PG_DB_OMOP="${PG_DB_OMOP:-omop}"

psql_db "$PG_DB_OMOP" <<'SQL'
BEGIN;
DO $$
DECLARE cur text; prev text;
BEGIN
  SELECT release_schema INTO cur FROM public.omop_release WHERE status = 'active';
  SELECT release_schema INTO prev FROM public.omop_release
   WHERE status = 'archived' ORDER BY published_at DESC LIMIT 1;
  IF cur IS NULL OR prev IS NULL THEN
    RAISE EXCEPTION 'Pas de release précédente disponible pour un retour arrière';
  END IF;
  EXECUTE format('ALTER SCHEMA cdm RENAME TO %I', cur);
  EXECUTE format('ALTER SCHEMA %I RENAME TO cdm', prev);
  UPDATE public.omop_release SET status = 'rolled_back' WHERE release_schema = cur;
  UPDATE public.omop_release SET status = 'active'      WHERE release_schema = prev;
  RAISE NOTICE 'Release active : % (retirée : %)', prev, cur;
END $$;
COMMIT;
SELECT release_schema, published_at, status FROM public.omop_release ORDER BY published_at DESC LIMIT 6;
SQL
