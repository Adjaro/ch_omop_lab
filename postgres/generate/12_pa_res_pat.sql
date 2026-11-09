-- Responsabilités / mouvements fictifs, type CORA :
--   M = responsabilité médicale, H = hébergement.
-- Pièges volontaires pour la couche silver :
--   * ~10 % des séjours ont une UF d'hébergement ≠ UF médicale (divergence)
--   * ~14 % des H ont une version obsolète (même pas_ips + per_deb, per_fin plus ancienne)
--   * ~2 % des H ont une version "ouverte" (per_fin NULL) en doublon
BEGIN;
DROP TABLE IF EXISTS bronze.pa_res_pat;
CREATE TABLE bronze.pa_res_pat (
    pa_res_pat_ide     bigint      NOT NULL,
    pas_ips            bigint      NOT NULL,
    pa_res_pat_typ     char(1)     NOT NULL,
    ufo_ide            integer     NOT NULL,
    pa_res_pat_per_deb timestamp   NOT NULL,
    pa_res_pat_per_fin timestamp,
    _batch_id          bigint      NOT NULL,
    _ingested_at       timestamptz NOT NULL DEFAULT now()
);

INSERT INTO bronze.pa_res_pat
    (pa_res_pat_ide, pas_ips, pa_res_pat_typ, ufo_ide, pa_res_pat_per_deb, pa_res_pat_per_fin, _batch_id)
-- Responsabilité médicale
SELECT g, g, 'M', gen.pas_uf(g), gen.pas_start(g), gen.pas_end(g), p.batch_id
FROM gen.params p CROSS JOIN LATERAL generate_series(1, p.n_pas) g
UNION ALL
-- Hébergement (version valide)
SELECT p.n_pas + g, g, 'H',
       CASE WHEN g % 10 = 0 THEN gen.pas_uf(g + 1) ELSE gen.pas_uf(g) END,
       gen.pas_start(g), gen.pas_end(g), p.batch_id
FROM gen.params p CROSS JOIN LATERAL generate_series(1, p.n_pas) g
UNION ALL
-- Hébergement : version obsolète (à éliminer par la dédup silver)
SELECT 2 * p.n_pas + g, g, 'H', gen.pas_uf(g + 2),
       gen.pas_start(g), gen.pas_start(g) + interval '1 hour', p.batch_id
FROM gen.params p CROSS JOIN LATERAL generate_series(1, p.n_pas) g
WHERE g % 7 = 0
UNION ALL
-- Hébergement : doublon "ouvert" (per_fin NULL) — NULLS LAST doit l'écarter
SELECT 3 * p.n_pas + g, g, 'H', gen.pas_uf(g + 3),
       gen.pas_start(g), NULL, p.batch_id
FROM gen.params p CROSS JOIN LATERAL generate_series(1, p.n_pas) g
WHERE g % 50 = 0 AND gen.pas_end(g) IS NOT NULL;
COMMIT;
