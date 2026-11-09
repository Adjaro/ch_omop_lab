CREATE TABLE cdm_source (
    cdm_source_name                varchar(255) NOT NULL,
    cdm_source_abbreviation        varchar(25)  NOT NULL,
    cdm_holder                     varchar(255) NOT NULL,
    source_description             text         NULL,
    source_documentation_reference varchar(255) NULL,
    cdm_etl_reference              varchar(255) NULL,
    source_release_date            date         NOT NULL,
    cdm_release_date               date         NOT NULL,
    cdm_version                    varchar(10)  NULL,
    cdm_version_concept_id         integer      NOT NULL,
    vocabulary_version             varchar(20)  NOT NULL
);
