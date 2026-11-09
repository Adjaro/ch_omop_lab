CREATE TABLE procedure_occurrence (
    procedure_occurrence_id     integer     NOT NULL,
    person_id                   integer     NOT NULL,
    procedure_concept_id        integer     NOT NULL,
    procedure_date              date        NOT NULL,
    procedure_datetime          timestamp   NULL,
    procedure_end_date          date        NULL,
    procedure_end_datetime      timestamp   NULL,
    procedure_type_concept_id   integer     NOT NULL,
    modifier_concept_id         integer     NULL,
    quantity                    integer     NULL,
    provider_id                 integer     NULL,
    visit_occurrence_id         integer     NULL,
    visit_detail_id             integer     NULL,
    procedure_source_value      varchar(50) NULL,
    procedure_source_concept_id integer     NULL,
    modifier_source_value       varchar(50) NULL
);
