-- Diagnostics CIM-10 fictifs : 1 DP + 2 DAS par séjour
BEGIN;
DROP TABLE IF EXISTS bronze.diag;
CREATE TABLE bronze.diag (
    diag_id      bigint      NOT NULL,
    pas_ips      bigint      NOT NULL,
    code_cim10   text        NOT NULL,
    type_diag    text        NOT NULL,
    date_diag    date        NOT NULL,
    _batch_id    bigint      NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

WITH codes AS (
    SELECT array_agg(source_code ORDER BY source_code) AS arr, count(*) AS n
    FROM bronze.ref_vocab_map WHERE source_vocab = 'CIM10'
)
INSERT INTO bronze.diag (diag_id, pas_ips, code_cim10, type_diag, date_diag, _batch_id)
SELECT s.g, s.pas,
       c.arr[1 + (s.g * 2654435761 + s.pas) % c.n],
       CASE WHEN (s.g - 1) % 3 = 0 THEN 'DP' ELSE 'DAS' END,
       gen.pas_start(s.pas)::date,
       s.batch_id
FROM codes c,
     LATERAL (SELECT g, (g - 1) / 3 + 1 AS pas, p.batch_id
              FROM gen.params p CROSS JOIN LATERAL generate_series(1, 3 * p.n_pas) g) s;
COMMIT;
