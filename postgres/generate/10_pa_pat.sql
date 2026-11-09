-- Patients fictifs (pseudonymisés : aucun nom, uniquement IPP fictif)
-- Table en insertion seule : une mise à jour (ex. décès) arrive comme une nouvelle version (_batch_id supérieur).
BEGIN;
DROP TABLE IF EXISTS bronze.pa_pat;
CREATE TABLE bronze.pa_pat (
    pat_ipp      bigint      NOT NULL,
    sexe         char(1)     NOT NULL,
    date_naiss   date        NOT NULL,
    code_postal  text        NOT NULL,
    date_deces   date,
    _batch_id    bigint      NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO bronze.pa_pat (pat_ipp, sexe, date_naiss, code_postal, date_deces, _batch_id)
SELECT 10000000 + g,
       CASE WHEN random() < 0.51 THEN 'F' ELSE 'M' END,
       b.dn,
       '130' || lpad((1 + g % 16)::text, 2, '0'),
       CASE WHEN b.dn < date '1960-01-01' AND random() < 0.08
            THEN date '2018-01-01' + (random() * 2900)::int END,
       p.batch_id
FROM gen.params p
CROSS JOIN LATERAL generate_series(1, p.n_pat) g
CROSS JOIN LATERAL (SELECT date '1930-01-01' + (random() * 33000 + g * 0)::int AS dn) b;
COMMIT;
