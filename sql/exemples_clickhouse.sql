-- =====================================================================
-- Requêtes d'exploration à coller dans CH-UI (http://localhost:3488),
-- la console intégrée (http://localhost:8123/play) ou DBeaver.
-- =====================================================================

-- 1. Volumétrie et compression par couche
SELECT database, table,
       formatReadableQuantity(sum(rows))              AS lignes,
       formatReadableSize(sum(data_uncompressed_bytes)) AS brut,
       formatReadableSize(sum(bytes_on_disk))          AS sur_disque,
       round(sum(data_uncompressed_bytes) / sum(bytes_on_disk), 1) AS ratio
FROM system.parts
WHERE active AND database IN ('bronze_ch', 'silver', 'gold_omop', 'gold_analytics')
GROUP BY database, table
ORDER BY sum(bytes_on_disk) DESC;

-- 2. Le pipeline incrémental : lignes par lot dans chaque couche
SELECT * FROM (
    SELECT 'bronze' AS couche, _batch_id AS lot, count() AS lignes FROM bronze_ch.bz_bio GROUP BY lot
    UNION ALL
    SELECT 'silver', _batch_id, count() FROM silver.slv_bio GROUP BY _batch_id
    UNION ALL
    SELECT 'gold', _src_batch_id, count() FROM gold_omop.measurement FINAL WHERE _is_deleted = 0 GROUP BY _src_batch_id
)
ORDER BY couche, lot;

-- 3. Suppressions logiques (oppositions) en attente de fusion
SELECT _is_deleted, count() FROM gold_omop.measurement GROUP BY _is_deleted;

-- 4. Hub d'identité : les identifiants restent stables d'un lot à l'autre
SELECT first_batch_id AS lot, count() AS nouveaux_patients, min(person_id), max(person_id)
FROM silver.hub_person GROUP BY lot ORDER BY lot;

-- 5. Qualité : séjours dont l'UF d'hébergement diffère de l'UF médicale
SELECT uf_med, uf_heb, count() AS n
FROM silver.slv_stay WHERE uf_divergente
GROUP BY uf_med, uf_heb ORDER BY n DESC LIMIT 20;

-- 6. Mapping : taux de codes non mappés par vocabulaire (concept_id = 0)
SELECT 'CIM10' AS vocab, round(100 * countIf(concept_id = 0) / count(), 2) AS pct_non_mappes FROM silver.slv_diag
UNION ALL SELECT 'CCAM', round(100 * countIf(concept_id = 0) / count(), 2) FROM silver.slv_acte
UNION ALL SELECT 'BIO',  round(100 * countIf(concept_id = 0) / count(), 2) FROM silver.slv_bio
UNION ALL SELECT 'UCD',  round(100 * countIf(concept_id = 0) / count(), 2) FROM silver.slv_presc;

-- 7. Cohorte en une requête : diabétiques avec HbA1c > 7 (patients, séjours, valeur médiane)
SELECT uniqExact(c.person_id) AS patients, uniqExact(c.visit_occurrence_id) AS sejours,
       quantile(0.5)(toFloat64(m.value_as_number)) AS hba1c_mediane
FROM (SELECT person_id, visit_occurrence_id FROM gold_omop.condition_occurrence FINAL
      WHERE _is_deleted = 0 AND condition_source_value = 'E11.9') c
INNER JOIN (SELECT visit_occurrence_id, value_as_number FROM gold_omop.measurement FINAL
            WHERE _is_deleted = 0 AND measurement_source_value = 'HBA1C' AND value_as_number > 7) m
USING (visit_occurrence_id);

-- 8. Lookup dictionnaire (O(1), sans jointure)
SELECT dictGet('silver.dict_vocab', 'source_label', tuple('CIM10', 'I10')) AS libelle,
       dictGet('silver.dict_vocab', 'target_concept_id', tuple('CIM10', 'I10')) AS concept_id;

-- 9. Requêtes les plus coûteuses de la dernière heure (pour optimiser)
SELECT query_duration_ms, formatReadableSize(memory_usage) AS memoire,
       formatReadableQuantity(read_rows) AS lignes_lues, substring(query, 1, 120) AS requete
FROM system.query_log
WHERE type = 'QueryFinish' AND event_time > now() - INTERVAL 1 HOUR
ORDER BY query_duration_ms DESC LIMIT 10;
