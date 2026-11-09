-- Séjours / passages fictifs (≈ 3 par patient à scale=1)
BEGIN;
DROP TABLE IF EXISTS bronze.pa_pas;
CREATE TABLE bronze.pa_pas (
    pas_ips      bigint      NOT NULL,
    iep_ide      bigint      NOT NULL,
    pat_ipp      bigint      NOT NULL,
    type_sejour  text        NOT NULL,
    pas_per_deb  timestamp   NOT NULL,
    pas_per_fin  timestamp,
    mode_entree  text        NOT NULL,
    mode_sortie  text,
    _batch_id    bigint      NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO bronze.pa_pas
    (pas_ips, iep_ide, pat_ipp, type_sejour, pas_per_deb, pas_per_fin, mode_entree, mode_sortie, _batch_id)
SELECT g,
       500000000 + g,
       10000000 + gen.pas_pat(g, p.n_pat),
       gen.pas_type(g),
       gen.pas_start(g),
       gen.pas_end(g),
       CASE gen.pas_type(g) WHEN 'URG' THEN 'URG' WHEN 'HC' THEN (CASE WHEN g % 3 = 0 THEN 'URG' ELSE 'DOM' END) ELSE 'DOM' END,
       CASE WHEN gen.pas_end(g) IS NULL THEN NULL
            WHEN g % 211 = 0 THEN 'DCD'
            WHEN g % 17 = 0  THEN 'MUT'
            ELSE 'DOM' END,
       p.batch_id
FROM gen.params p
CROSS JOIN LATERAL generate_series(1, p.n_pas) g;
COMMIT;
