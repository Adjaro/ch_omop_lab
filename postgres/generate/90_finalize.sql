-- Index APRÈS chargement (bien plus rapide qu'avant), puis statistiques.
-- Les index B-tree servent au benchmark Postgres "équitable" ; les BRIN sur _batch_id
-- servent au filtre incrémental poussé par ClickHouse (quasi gratuits en taille).
SET maintenance_work_mem = '1GB';
SET max_parallel_maintenance_workers = 4;

ALTER TABLE bronze.pa_pat     ADD PRIMARY KEY (pat_ipp, _batch_id);
ALTER TABLE bronze.pa_pas     ADD PRIMARY KEY (pas_ips);
ALTER TABLE bronze.pa_res_pat ADD PRIMARY KEY (pa_res_pat_ide);
ALTER TABLE bronze.diag       ADD PRIMARY KEY (diag_id);
ALTER TABLE bronze.actes      ADD PRIMARY KEY (acte_id);
ALTER TABLE bronze.bio        ADD PRIMARY KEY (bio_id);
ALTER TABLE bronze.pharma     ADD PRIMARY KEY (presc_id);

CREATE INDEX ON bronze.pa_pas (pat_ipp);
CREATE INDEX ON bronze.pa_res_pat (pas_ips, pa_res_pat_typ);
CREATE INDEX ON bronze.diag (pas_ips);
CREATE INDEX ON bronze.diag (code_cim10);
CREATE INDEX ON bronze.actes (pas_ips);
CREATE INDEX ON bronze.bio (pas_ips);
CREATE INDEX ON bronze.bio (code_analyse, date_prel);
CREATE INDEX ON bronze.pharma (pas_ips);

CREATE INDEX ON bronze.pa_pat     USING brin (_batch_id);
CREATE INDEX ON bronze.pa_pas     USING brin (_batch_id);
CREATE INDEX ON bronze.pa_res_pat USING brin (_batch_id);
CREATE INDEX ON bronze.diag       USING brin (_batch_id);
CREATE INDEX ON bronze.actes      USING brin (_batch_id);
CREATE INDEX ON bronze.bio        USING brin (_batch_id);
CREATE INDEX ON bronze.pharma     USING brin (_batch_id);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ch_reader') THEN
    GRANT USAGE ON SCHEMA bronze TO ch_reader;
    GRANT SELECT ON ALL TABLES IN SCHEMA bronze TO ch_reader;
  END IF;
END $$;

VACUUM (ANALYZE) bronze.pa_pat, bronze.pa_pas, bronze.pa_res_pat, bronze.diag,
                 bronze.actes, bronze.bio, bronze.pharma, bronze.ref_vocab_map;

SELECT relname AS table_bronze,
       to_char(n_live_tup, 'FM999G999G999') AS lignes,
       pg_size_pretty(pg_total_relation_size(relid)) AS taille_totale
FROM pg_stat_user_tables
WHERE schemaname = 'bronze'
ORDER BY pg_total_relation_size(relid) DESC;

SELECT pg_size_pretty(sum(pg_total_relation_size(relid))) AS taille_bronze_totale
FROM pg_stat_user_tables WHERE schemaname = 'bronze';
