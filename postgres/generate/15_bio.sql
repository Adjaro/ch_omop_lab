-- Résultats de biologie fictifs : 10 par séjour (la plus grosse table, ~60 % du volume)
BEGIN;
DROP TABLE IF EXISTS bronze.bio;
CREATE TABLE bronze.bio (
    bio_id       bigint        NOT NULL,
    pas_ips      bigint        NOT NULL,
    pat_ipp      bigint        NOT NULL,
    code_analyse text          NOT NULL,
    valeur       numeric(12,3) NOT NULL,
    unite        text          NOT NULL,
    borne_inf    numeric(12,3),
    borne_sup    numeric(12,3),
    date_prel    timestamp     NOT NULL,
    _batch_id    bigint        NOT NULL,
    _ingested_at timestamptz   NOT NULL DEFAULT now()
);

WITH ref AS (
    SELECT array_agg(source_code ORDER BY source_code) AS code,
           array_agg(extra_num_1 ORDER BY source_code) AS moy,
           array_agg(extra_num_2 ORDER BY source_code) AS sd,
           array_agg(extra_num_3 ORDER BY source_code) AS lo,
           array_agg(extra_num_4 ORDER BY source_code) AS hi,
           array_agg(extra_txt   ORDER BY source_code) AS unit,
           count(*) AS n
    FROM bronze.ref_vocab_map WHERE source_vocab = 'BIO'
)
INSERT INTO bronze.bio
    (bio_id, pas_ips, pat_ipp, code_analyse, valeur, unite, borne_inf, borne_sup, date_prel, _batch_id)
SELECT s.g, s.pas, 10000000 + gen.pas_pat(s.pas, s.n_pat),
       r.code[s.i],
       round(greatest(0, r.moy[s.i] + r.sd[s.i] * (random() + random() + random() - 1.5) * 1.4)::numeric, 3),
       r.unit[s.i], r.lo[s.i], r.hi[s.i],
       gen.pas_start(s.pas) + ((s.g % 10) * (gen.pas_los(s.pas) * 24 + 6) / 10.0) * interval '1 hour',
       s.batch_id
FROM ref r,
     LATERAL (SELECT g, (g - 1) / 10 + 1 AS pas, p.n_pat, p.batch_id,
                     (1 + (g * 2654435761) % r.n)::int AS i
              FROM gen.params p CROSS JOIN LATERAL generate_series(1, 10 * p.n_pas) g) s;
COMMIT;
