CREATE TABLE death (
    person_id               integer     NOT NULL,
    death_date              date        NOT NULL,
    death_datetime          timestamp   NULL,
    death_type_concept_id   integer     NULL,
    cause_concept_id        integer     NULL,
    cause_source_value      varchar(50) NULL,
    cause_source_concept_id integer     NULL
);
