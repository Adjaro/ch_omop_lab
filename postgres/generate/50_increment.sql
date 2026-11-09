-- =====================================================================
-- Simule un NOUVEAU LOT d'ingestion (batch N+1), en insertion seule :
--   * nouveaux patients (+0,2 %) et nouveaux séjours récents (+1 %) avec leurs événements
--   * corrections : nouvelle version d'hébergement H (UF corrigée) sur 0,5 % des séjours
--   * mises à jour patient : déclaration de décès (nouvelle version de pa_pat)
--   * oppositions patient (droit d'opposition) : à propager en suppression logique dans le gold
-- Lancer autant de fois que voulu : chaque exécution crée un batch supplémentaire.
-- =====================================================================
BEGIN;

CREATE TABLE IF NOT EXISTS bronze.pat_opposition (
    pat_ipp          bigint      NOT NULL,
    date_opposition  date        NOT NULL,
    _batch_id        bigint      NOT NULL,
    _ingested_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TEMP TABLE b ON COMMIT DROP AS
SELECT (SELECT max(_batch_id) FROM bronze.pa_pas) + 1               AS batch_id,
       (SELECT max(pas_ips)   FROM bronze.pa_pas)                   AS max_pas,
       (SELECT max(pat_ipp)   FROM bronze.pa_pat)                   AS max_ipp,
       (SELECT max(pa_res_pat_ide) FROM bronze.pa_res_pat)          AS max_res,
       (SELECT max(diag_id)   FROM bronze.diag)                     AS max_diag,
       (SELECT max(acte_id)   FROM bronze.actes)                    AS max_acte,
       (SELECT max(bio_id)    FROM bronze.bio)                      AS max_bio,
       (SELECT max(presc_id)  FROM bronze.pharma)                   AS max_presc,
       greatest(10, p.n_pat / 500)                                  AS n_new_pat,
       greatest(30, p.n_pas / 100)                                  AS n_new_pas,
       p.n_pat
FROM gen.params p;

-- Nouveaux patients
INSERT INTO bronze.pa_pat (pat_ipp, sexe, date_naiss, code_postal, date_deces, _batch_id)
SELECT b.max_ipp + g,
       CASE WHEN random() < 0.51 THEN 'F' ELSE 'M' END,
       date '1940-01-01' + (random() * 30000 + g * 0)::int,
       '130' || lpad((1 + g % 16)::text, 2, '0'),
       NULL, b.batch_id
FROM b CROSS JOIN LATERAL generate_series(1, b.n_new_pat) g;

-- Nouveaux séjours récents (30 derniers jours), patients existants ou nouveaux
CREATE TEMP TABLE new_pas ON COMMIT DROP AS
SELECT b.max_pas + g                                                        AS pas_ips,
       CASE WHEN g % 5 = 0 THEN b.max_ipp + 1 + (g % b.n_new_pat)
            ELSE 10000000 + gen.pas_pat(g * 31, b.n_pat) END                 AS pat_ipp,
       gen.pas_type(g)                                                       AS type_sejour,
       date_trunc('hour', localtimestamp) - ((g * 37) % 720) * interval '1 hour' AS deb,
       gen.pas_los(g)                                                        AS los,
       b.batch_id
FROM b CROSS JOIN LATERAL generate_series(1, b.n_new_pas) g;

INSERT INTO bronze.pa_pas
    (pas_ips, iep_ide, pat_ipp, type_sejour, pas_per_deb, pas_per_fin, mode_entree, mode_sortie, _batch_id)
SELECT pas_ips, 500000000 + pas_ips, pat_ipp, type_sejour, deb,
       deb + los * interval '1 day' + interval '4 hour',
       CASE type_sejour WHEN 'URG' THEN 'URG' ELSE 'DOM' END, 'DOM', batch_id
FROM new_pas;

INSERT INTO bronze.pa_res_pat
    (pa_res_pat_ide, pas_ips, pa_res_pat_typ, ufo_ide, pa_res_pat_per_deb, pa_res_pat_per_fin, _batch_id)
SELECT b.max_res + row_number() OVER (), x.pas_ips, x.typ, gen.pas_uf(x.pas_ips), x.deb, x.fin, b.batch_id
FROM b, (SELECT pas_ips, t.typ, deb, deb + los * interval '1 day' + interval '4 hour' AS fin
         FROM new_pas CROSS JOIN (VALUES ('M'), ('H')) t(typ)) x;

-- Correction : nouvelle version H (UF corrigée, per_fin plus récente) sur 0,5 % des séjours existants
INSERT INTO bronze.pa_res_pat
    (pa_res_pat_ide, pas_ips, pa_res_pat_typ, ufo_ide, pa_res_pat_per_deb, pa_res_pat_per_fin, _batch_id)
SELECT b.max_res + 1000000 + r.pas_ips, r.pas_ips, 'H', gen.pas_uf(r.pas_ips + 5),
       r.pa_res_pat_per_deb, r.pa_res_pat_per_fin + interval '2 hour', b.batch_id
FROM b, bronze.pa_res_pat r
WHERE r.pa_res_pat_typ = 'H' AND r.pa_res_pat_per_fin IS NOT NULL
  AND r.pas_ips % 200 = b.batch_id % 200 AND r.pas_ips <= b.max_pas
  AND r._batch_id < b.batch_id
  AND r.pa_res_pat_ide = (SELECT min(pa_res_pat_ide) FROM bronze.pa_res_pat r2
                          WHERE r2.pas_ips = r.pas_ips AND r2.pa_res_pat_typ = 'H'
                            AND r2.pa_res_pat_per_fin IS NOT NULL);

-- Événements des nouveaux séjours
INSERT INTO bronze.diag (diag_id, pas_ips, code_cim10, type_diag, date_diag, _batch_id)
SELECT b.max_diag + row_number() OVER (), n.pas_ips,
       (SELECT array_agg(source_code ORDER BY source_code) FROM bronze.ref_vocab_map WHERE source_vocab = 'CIM10')
         [1 + ((n.pas_ips * 3 + k) * 2654435761) % 40],
       CASE WHEN k = 0 THEN 'DP' ELSE 'DAS' END, n.deb::date, b.batch_id
FROM b, new_pas n CROSS JOIN generate_series(0, 2) k;

INSERT INTO bronze.actes (acte_id, pas_ips, code_ccam, date_acte, _batch_id)
SELECT b.max_acte + row_number() OVER (), n.pas_ips,
       (SELECT array_agg(source_code ORDER BY source_code) FROM bronze.ref_vocab_map WHERE source_vocab = 'CCAM')
         [1 + ((n.pas_ips * 2 + k) * 2654435761) % 25],
       n.deb + k * interval '2 hour', b.batch_id
FROM b, new_pas n CROSS JOIN generate_series(0, 1) k;

INSERT INTO bronze.bio
    (bio_id, pas_ips, pat_ipp, code_analyse, valeur, unite, borne_inf, borne_sup, date_prel, _batch_id)
SELECT b.max_bio + row_number() OVER (), n.pas_ips, n.pat_ipp, r.source_code,
       round(greatest(0, r.extra_num_1 + r.extra_num_2 * (random() - 0.5) * 2)::numeric, 3),
       r.extra_txt, r.extra_num_3, r.extra_num_4, n.deb + k * interval '1 hour', b.batch_id
FROM b, new_pas n CROSS JOIN generate_series(0, 9) k
JOIN (SELECT *, row_number() OVER (ORDER BY source_code) - 1 AS idx
      FROM bronze.ref_vocab_map WHERE source_vocab = 'BIO') r ON r.idx = (n.pas_ips + k) % 15;

INSERT INTO bronze.pharma
    (presc_id, pas_ips, pat_ipp, code_ucd, dose, voie, date_debut, date_fin, _batch_id)
SELECT b.max_presc + row_number() OVER (), n.pas_ips, n.pat_ipp, r.source_code,
       r.extra_num_1, r.extra_txt, n.deb + k * interval '2 hour',
       n.deb + (n.los + 0) * interval '1 day' + interval '3 hour', b.batch_id
FROM b, new_pas n CROSS JOIN generate_series(0, 2) k
JOIN (SELECT *, row_number() OVER (ORDER BY source_code) - 1 AS idx
      FROM bronze.ref_vocab_map WHERE source_vocab = 'UCD') r ON r.idx = (n.pas_ips * 3 + k) % 20;

-- Mise à jour patient : décès déclaré (nouvelle version de la ligne patient)
INSERT INTO bronze.pa_pat (pat_ipp, sexe, date_naiss, code_postal, date_deces, _batch_id)
SELECT DISTINCT ON (p.pat_ipp) p.pat_ipp, p.sexe, p.date_naiss, p.code_postal,
       current_date - (p.pat_ipp % 20)::int, b.batch_id
FROM b, bronze.pa_pat p
WHERE p.pat_ipp % 1009 = b.batch_id % 1009 AND p.date_deces IS NULL AND p.date_naiss < date '1950-01-01'
ORDER BY p.pat_ipp, p._batch_id DESC;

-- Oppositions : quelques patients exercent leur droit d'opposition
INSERT INTO bronze.pat_opposition (pat_ipp, date_opposition, _batch_id)
SELECT DISTINCT p.pat_ipp, current_date, b.batch_id
FROM b, bronze.pa_pat p
WHERE p.pat_ipp % 4999 = b.batch_id % 4999;

COMMIT;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ch_reader') THEN
    GRANT SELECT ON bronze.pat_opposition TO ch_reader;
  END IF;
END $$;

ANALYZE bronze.pa_pat, bronze.pa_pas, bronze.pa_res_pat, bronze.diag, bronze.actes, bronze.bio, bronze.pharma, bronze.pat_opposition;

SELECT 'batch ' || max(_batch_id) || ' ingéré' AS statut,
       count(*) FILTER (WHERE _batch_id = (SELECT max(_batch_id) FROM bronze.pa_pas)) AS nouveaux_sejours
FROM bronze.pa_pas;
