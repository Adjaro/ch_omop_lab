-- Prescriptions fictives (codes UCD inventés) : 3 par séjour
BEGIN;
DROP TABLE IF EXISTS bronze.pharma;
CREATE TABLE bronze.pharma (
    presc_id     bigint        NOT NULL,
    pas_ips      bigint        NOT NULL,
    pat_ipp      bigint        NOT NULL,
    code_ucd     text          NOT NULL,
    dose         numeric(10,2) NOT NULL,
    voie         text          NOT NULL,
    date_debut   timestamp     NOT NULL,
    date_fin     timestamp,
    _batch_id    bigint        NOT NULL,
    _ingested_at timestamptz   NOT NULL DEFAULT now()
);

WITH ref AS (
    SELECT array_agg(source_code ORDER BY source_code) AS code,
           array_agg(extra_num_1 ORDER BY source_code) AS dose,
           array_agg(extra_txt   ORDER BY source_code) AS voie,
           count(*) AS n
    FROM bronze.ref_vocab_map WHERE source_vocab = 'UCD'
)
INSERT INTO bronze.pharma
    (presc_id, pas_ips, pat_ipp, code_ucd, dose, voie, date_debut, date_fin, _batch_id)
SELECT s.g, s.pas, 10000000 + gen.pas_pat(s.pas, s.n_pat),
       r.code[s.i],
       r.dose[s.i] * (1 + (s.g % 2)),
       r.voie[s.i],
       s.deb,
       s.deb + (CASE WHEN gen.pas_los(s.pas) = 0 THEN 0 ELSE 1 + s.g % gen.pas_los(s.pas) END) * interval '1 day',
       s.batch_id
FROM ref r,
     LATERAL (SELECT g, (g - 1) / 3 + 1 AS pas, p.n_pat, p.batch_id,
                     (1 + (g * 2654435761) % r.n)::int AS i,
                     gen.pas_start((g - 1) / 3 + 1) + ((g % 3) * 2) * interval '1 hour' AS deb
              FROM gen.params p CROSS JOIN LATERAL generate_series(1, 3 * p.n_pas) g) s;
COMMIT;
