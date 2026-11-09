CREATE TABLE condition_occurrence (
    condition_occurrence_id       integer     NOT NULL,
    person_id                     integer     NOT NULL,
    condition_concept_id          integer     NOT NULL,
    condition_start_date          date        NOT NULL,
    condition_start_datetime      timestamp   NULL,
    condition_end_date            date        NULL,
    condition_end_datetime        timestamp   NULL,
    condition_type_concept_id     integer     NOT NULL,
    condition_status_concept_id   integer     NULL,
    stop_reason                   varchar(20) NULL,
    provider_id                   integer     NULL,
    visit_occurrence_id           integer     NULL,
    visit_detail_id               integer     NULL,
    condition_source_value        varchar(50) NULL,
    condition_source_concept_id   integer     NULL,
    condition_status_source_value varchar(50) NULL
);
