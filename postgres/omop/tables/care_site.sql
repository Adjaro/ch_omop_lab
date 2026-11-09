CREATE TABLE care_site (
    care_site_id                  integer      NOT NULL,
    care_site_name                varchar(255) NULL,
    place_of_service_concept_id   integer      NULL,
    location_id                   integer      NULL,
    care_site_source_value        varchar(50)  NULL,
    place_of_service_source_value varchar(50)  NULL
);
