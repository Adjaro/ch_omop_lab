-- Clés primaires + index OHDSI standard, créés APRÈS le chargement d'une release.
-- Appelé avec : psql -v schema=cdm_YYYYMMDD_HHMM -f indexes.sql
SET search_path TO :"schema";
SET maintenance_work_mem = '1GB';
SET max_parallel_maintenance_workers = 4;

ALTER TABLE person               ADD PRIMARY KEY (person_id);
ALTER TABLE observation_period   ADD PRIMARY KEY (observation_period_id);
ALTER TABLE visit_occurrence     ADD PRIMARY KEY (visit_occurrence_id);
ALTER TABLE condition_occurrence ADD PRIMARY KEY (condition_occurrence_id);
ALTER TABLE procedure_occurrence ADD PRIMARY KEY (procedure_occurrence_id);
ALTER TABLE measurement          ADD PRIMARY KEY (measurement_id);
ALTER TABLE drug_exposure        ADD PRIMARY KEY (drug_exposure_id);
ALTER TABLE care_site            ADD PRIMARY KEY (care_site_id);

CREATE INDEX idx_observation_period_person ON observation_period (person_id);
CREATE INDEX idx_visit_person              ON visit_occurrence (person_id);
CREATE INDEX idx_visit_concept             ON visit_occurrence (visit_concept_id);
CREATE INDEX idx_condition_person          ON condition_occurrence (person_id);
CREATE INDEX idx_condition_concept         ON condition_occurrence (condition_concept_id);
CREATE INDEX idx_condition_visit           ON condition_occurrence (visit_occurrence_id);
CREATE INDEX idx_procedure_person          ON procedure_occurrence (person_id);
CREATE INDEX idx_procedure_concept         ON procedure_occurrence (procedure_concept_id);
CREATE INDEX idx_procedure_visit           ON procedure_occurrence (visit_occurrence_id);
CREATE INDEX idx_measurement_person        ON measurement (person_id);
CREATE INDEX idx_measurement_concept       ON measurement (measurement_concept_id);
CREATE INDEX idx_measurement_visit         ON measurement (visit_occurrence_id);
CREATE INDEX idx_drug_person               ON drug_exposure (person_id);
CREATE INDEX idx_drug_concept              ON drug_exposure (drug_concept_id);
CREATE INDEX idx_drug_visit                ON drug_exposure (visit_occurrence_id);
CREATE INDEX idx_death_person              ON death (person_id);
