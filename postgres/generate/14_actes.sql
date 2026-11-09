-- Actes fictifs (format CCAM, codes X... inventés) : 2 par séjour
BEGIN;
DROP TABLE IF EXISTS bronze.actes;
CREATE TABLE bronze.actes (
    acte_id      bigint      NOT NULL,
    pas_ips      bigint      NOT NULL,
    code_ccam    text        NOT NULL,
    date_acte    timestamp   NOT NULL,
    _batch_id    bigint      NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

WITH codes AS (
    SELECT array_agg(source_code ORDER BY source_code) AS arr, count(*) AS n
    FROM bronze.ref_vocab_map WHERE source_vocab = 'CCAM'
)
INSERT INTO bronze.actes (acte_id, pas_ips, code_ccam, date_acte, _batch_id)
SELECT s.g, s.pas,
       c.arr[1 + (s.g * 2654435761 + s.pas * 7) % c.n],
       gen.pas_start(s.pas) + ((s.g * 7) % (gen.pas_los(s.pas) * 24 + 2)) * interval '1 hour',
       s.batch_id
FROM codes c,
     LATERAL (SELECT g, (g - 1) / 2 + 1 AS pas, p.batch_id
              FROM gen.params p CROSS JOIN LATERAL generate_series(1, 2 * p.n_pas) g) s;
COMMIT;
